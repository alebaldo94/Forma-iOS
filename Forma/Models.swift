import Foundation

// Specchio del JSON di /api/app/allenamenti (vedi workouts.js sul server).
struct Passo: Codable, Hashable {
    var scopo: String?
    var nome: String?
    var durata_sec: Int?
    var distanza_m: Int?
    var fc: [Int]?
}

struct Blocco: Codable, Hashable {
    var ripetizioni: Int
    var passi: [Passo]
}

struct Limiti: Codable, Hashable {
    var fcMax: Int?
    var fcMin: Int?
}

struct FormaWorkout: Codable, Identifiable, Hashable {
    let id: String
    var data: String          // YYYY-MM-DD
    var nome: String
    var sport: String         // corsa | bici | camminata
    var luogo: String         // outdoor | indoor
    var note: String?
    var riscaldamento: Passo?
    var blocchi: [Blocco]
    var defaticamento: Passo?
    var limiti: Limiti?
    var stato: String         // programmato | sul_watch | completato
    var completato: Bool?

    var giorno: Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: data)
    }
}

struct LoginResponse: Codable {
    let token: String
    let nome: String
}
