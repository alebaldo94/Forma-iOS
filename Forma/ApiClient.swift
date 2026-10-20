import Foundation

struct ApiError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct ApiClient {
    static let base = URL(string: "https://forma.appartiene.org")!
    var token: String?

    private func request(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        var req = URLRequest(url: Self.base.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 30
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ApiError(message: "Risposta non valida") }
        if http.statusCode == 401 && path != "api/login" { throw ApiError(message: "Sessione scaduta: accedi di nuovo") }
        guard (200..<300).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw ApiError(message: msg ?? "Errore \(http.statusCode)")
        }
        return data
    }

    func login(nome: String, cognome: String) async throws -> LoginResponse {
        let d = try await request("api/login", method: "POST", body: ["nome": nome, "cognome": cognome])
        return try JSONDecoder().decode(LoginResponse.self, from: d)
    }

    func workouts() async throws -> [FormaWorkout] {
        try JSONDecoder().decode([FormaWorkout].self, from: try await request("api/app/allenamenti"))
    }

    func setStato(id: String, stato: String) async throws {
        _ = try await request("api/app/stato", method: "POST", body: ["id": id, "stato": stato])
    }

    /// serieFC: coppie [secondi dall'inizio, bpm]
    func sendResult(id: String, inizio: Date, serieFC: [[Double]]) async throws {
        struct Body: Encodable { let id: String; let inizio: String; let serieFC: [[Double]] }
        _ = try await request("api/app/risultato", method: "POST",
                              body: Body(id: id, inizio: ISO8601DateFormatter().string(from: inizio), serieFC: serieFC))
    }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ v: Encodable) { value = v }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
