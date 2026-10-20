import Foundation
import HealthKit
import WorkoutKit

@MainActor
final class Session: ObservableObject {
    @Published var nome: String? = Keychain.get("nome")
    @Published var workouts: [FormaWorkout] = []
    @Published var messaggio: String?
    @Published var occupato = false

    private var api = ApiClient(token: Keychain.get("token"))
    private let health = HealthReader()
    var loggato: Bool { api.token != nil }

    func login(nome: String, cognome: String) async {
        occupato = true; defer { occupato = false }
        do {
            let r = try await ApiClient(token: nil).login(nome: nome, cognome: cognome)
            Keychain.set(r.token, for: "token"); Keychain.set(r.nome, for: "nome")
            api.token = r.token; self.nome = r.nome; messaggio = nil
            await refresh()
        } catch { messaggio = error.localizedDescription }
    }

    func logout() {
        Keychain.remove("token"); Keychain.remove("nome")
        api.token = nil; nome = nil; workouts = []
    }

    /// Scarica gli allenamenti, li allinea con quelli programmati sul Watch e invia i risultati di quelli gia' svolti.
    func refresh() async {
        guard loggato else { return }
        occupato = true; defer { occupato = false }
        do {
            workouts = try await api.workouts()
            await allineaWatch()
            await inviaRisultatiMancanti()
            workouts = try await api.workouts()
            messaggio = nil
        } catch {
            messaggio = error.localizedDescription
            if error.localizedDescription.hasPrefix("Sessione scaduta") { logout() }
        }
    }

    private func oggi() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    /// Programma sul Watch gli allenamenti futuri non svolti e toglie quelli cancellati sul server.
    func allineaWatch() async {
        guard WorkoutScheduler.isSupported else { messaggio = "Questo dispositivo non supporta gli allenamenti programmati"; return }
        let scheduler = WorkoutScheduler.shared
        var stato = await scheduler.authorizationState
        if stato == .notDetermined { stato = await scheduler.requestAuthorization() }
        guard stato == .authorized else { messaggio = "Consenti a Forma di programmare allenamenti: Impostazioni > Salute"; return }

        let voluti = workouts.filter { $0.completato != true && $0.data >= oggi() }
        let ids = Set(voluti.compactMap { UUID(uuidString: $0.id) })
        let presenti = await scheduler.scheduledWorkouts
        for s in presenti where !ids.contains(s.plan.id) {
            await scheduler.remove(s.plan, at: s.date)
        }
        let perId = Dictionary(presenti.map { ($0.plan.id, $0) }, uniquingKeysWith: { a, _ in a })
        for w in voluti {
            guard let uid = UUID(uuidString: w.id), let when = WorkoutBuilder.dateComponents(w) else { continue }
            let plan = WorkoutBuilder.plan(w)
            if let esistente = perId[uid] {
                // modificato sul server: ripianifica
                if esistente.plan != plan || esistente.date != when {
                    await scheduler.remove(esistente.plan, at: esistente.date)
                    await scheduler.schedule(plan, at: when)
                }
            } else {
                await scheduler.schedule(plan, at: when)
            }
            if w.stato == "programmato" { try? await api.setStato(id: w.id, stato: "sul_watch") }
        }
    }

    /// Per ogni allenamento di oggi o dei giorni scorsi non ancora completato cerca la sessione sul Watch e ne invia la FC.
    func inviaRisultatiMancanti() async {
        guard health.isAvailable else { return }
        let candidati = workouts.filter { $0.completato != true && $0.data <= oggi() }
        guard !candidati.isEmpty else { return }
        do { try await health.authorize() } catch { return }
        for w in candidati {
            guard let giorno = w.giorno else { continue }
            do {
                guard let hk = try await health.workout(on: giorno, activity: WorkoutBuilder.activity(w.sport)) else { continue }
                let serie = try await health.heartRate(for: hk)
                if serie.count >= 2 { try await api.sendResult(id: w.id, inizio: hk.startDate, serieFC: serie) }
            } catch { continue }
        }
    }
}
