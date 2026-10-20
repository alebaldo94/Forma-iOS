import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: Session
    @State private var nome = ""
    @State private var cognome = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Accedi a Forma") {
                    TextField("Nome", text: $nome).textContentType(.username).textInputAutocapitalization(.words).autocorrectionDisabled()
                    SecureField("Cognome (password)", text: $cognome).textContentType(.password)
                }
                if let m = session.messaggio { Section { Text(m).foregroundStyle(.red) } }
                Section {
                    Button(session.occupato ? "Accesso…" : "Entra") { Task { await session.login(nome: nome, cognome: cognome) } }
                        .disabled(nome.isEmpty || cognome.isEmpty || session.occupato)
                }
            }
            .navigationTitle("Forma")
        }
    }
}

struct WorkoutListView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        NavigationStack {
            List {
                if let m = session.messaggio { Text(m).foregroundStyle(.red) }
                if session.workouts.isEmpty && !session.occupato {
                    Text("Nessun allenamento in programma.").foregroundStyle(.secondary)
                }
                ForEach(session.workouts) { w in
                    NavigationLink(value: w) { Row(w: w) }
                }
            }
            .navigationTitle(session.nome.map { "Ciao \($0)" } ?? "Forma")
            .navigationDestination(for: FormaWorkout.self) { DetailView(w: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Esci") { session.logout() } }
            }
            .refreshable { await session.refresh() }
            .task { await session.refresh() }
            .overlay { if session.occupato && session.workouts.isEmpty { ProgressView() } }
        }
    }
}

private struct Row: View {
    let w: FormaWorkout
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(w.nome).font(.headline)
            HStack {
                Text(w.giorno?.formatted(.dateTime.weekday(.wide).day().month()) ?? w.data)
                Spacer()
                Text(stato).font(.caption).foregroundStyle(w.completato == true ? .green : .secondary)
            }.font(.subheadline).foregroundStyle(.secondary)
        }
    }
    private var stato: String {
        if w.completato == true { return "svolto" }
        return w.stato == "sul_watch" ? "sul Watch" : "da programmare"
    }
}

struct DetailView: View {
    @EnvironmentObject var session: Session
    let w: FormaWorkout

    var body: some View {
        List {
            if let n = w.note, !n.isEmpty { Section { Text(n) } }
            Section("Passi") {
                if let p = w.riscaldamento { StepRow(titolo: "Riscaldamento", p: p) }
                ForEach(Array(w.blocchi.enumerated()), id: \.offset) { _, b in
                    ForEach(Array(b.passi.enumerated()), id: \.offset) { _, p in
                        StepRow(titolo: (p.scopo == "recovery" ? "Recupero" : "Lavoro") + (b.ripetizioni > 1 ? " ×\(b.ripetizioni)" : ""), p: p)
                    }
                }
                if let p = w.defaticamento { StepRow(titolo: "Defaticamento", p: p) }
            }
            if let l = w.limiti {
                Section("Limiti FC") {
                    if let m = l.fcMax { Text("Massima \(m) bpm") }
                    if let m = l.fcMin { Text("Minima \(m) bpm") }
                }
            }
            Section {
                Text(w.completato == true
                     ? "Allenamento svolto: la frequenza cardiaca è stata inviata al tuo allenatore."
                     : "L'allenamento è nell'app Allenamento dell'Apple Watch. Avvialo da lì: durante la sessione vedi la tua frequenza cardiaca e ricevi un avviso quando esci dal range.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(w.nome)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Sincronizza") { Task { await session.refresh() } } }
        }
    }
}

private struct StepRow: View {
    let titolo: String
    let p: Passo
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(titolo)
                if let n = p.nome { Text(n).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(durata)
                if let fc = p.fc, fc.count == 2 { Text("\(fc[0])–\(fc[1]) bpm").font(.caption).foregroundStyle(.red) }
            }
        }
    }
    private var durata: String {
        if let s = p.durata_sec { return String(format: "%d:%02d", s / 60, s % 60) }
        if let m = p.distanza_m { return m >= 1000 ? String(format: "%.1f km", Double(m) / 1000) : "\(m) m" }
        return "libero"
    }
}
