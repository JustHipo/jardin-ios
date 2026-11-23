import Foundation
import os

protocol PlantNetServiceProtocol: Sendable {
    func identifyPlant(images: [Data]) async throws -> PlantNetIdentifyResponse
    func identifyDiseases(images: [Data]) async throws -> PlantNetDiseaseResponse
}

/// Ported from the old codebase, which the design session called "funciona bien". Changes:
/// the key is embedded under PlantNet's non-profit plan instead of asked from the user
/// (P1/H6), and the 15 `print()` calls become `os.Logger`.
nonisolated final class PlantNetService: PlantNetServiceProtocol, Sendable {
    private let apiKey: String
    private let baseURL = "https://my-api.plantnet.org/v2"
    private let lang: String

    init(apiKey: String, lang: String = "es") {
        self.apiKey = apiKey
        self.lang = lang
    }

    func identifyPlant(images: [Data]) async throws -> PlantNetIdentifyResponse {
        // `include-related-images=true` is what actually puts reference photos in the
        // response — verified live: without it, every result's `images` comes back nil,
        // not merely empty. Confirmed against the real API on 2026-09-13.
        let urlString = "\(baseURL)/identify/all?api-key=\(apiKey)&nb-results=5&lang=\(lang)&no-reject=false&include-related-images=true"
        let (data, response) = try await uploadMultipart(urlString: urlString, images: images)

        guard let http = response as? HTTPURLResponse else { throw PlantNetError.invalidResponse }
        AppLog.plantData.debug("PlantNet identify status: \(http.statusCode)")

        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 429 { throw PlantNetError.rateLimited }
            throw PlantNetError.httpError(http.statusCode)
        }

        return try JSONDecoder().decode(PlantNetIdentifyResponse.self, from: data)
    }

    func identifyDiseases(images: [Data]) async throws -> PlantNetDiseaseResponse {
        let urlString = "\(baseURL)/diseases/identify?api-key=\(apiKey)&nb-results=5&lang=\(lang)"
        let (data, response) = try await uploadMultipart(urlString: urlString, images: images)

        guard let http = response as? HTTPURLResponse else { throw PlantNetError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw PlantNetError.httpError(http.statusCode) }

        return try JSONDecoder().decode(PlantNetDiseaseResponse.self, from: data)
    }

    private func uploadMultipart(urlString: String, images: [Data]) async throws -> (Data, URLResponse) {
        guard let url = URL(string: urlString) else { throw PlantNetError.invalidURL }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()
        for (index, imageData) in images.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"images\"; filename=\"image\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"organs\"\r\n\r\n".data(using: .utf8)!)
            body.append("auto\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await URLSession.shared.data(for: request)
    }
}

enum PlantNetError: Error, LocalizedError, Sendable {
    case invalidURL, invalidResponse, httpError(Int), rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "plantnet.error.url", defaultValue: "URL de PlantNet inválida.")
        case .invalidResponse: String(localized: "plantnet.error.response", defaultValue: "Respuesta inválida de PlantNet.")
        case .httpError(let code): String(localized: "plantnet.error.http", defaultValue: "PlantNet devolvió un error.") + " (\(code))"
        case .rateLimited: String(localized: "plantnet.error.rateLimited", defaultValue: "Se alcanzó el límite diario de PlantNet.")
        }
    }
}
