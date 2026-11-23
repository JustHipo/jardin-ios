import Foundation

/// Fetches Open-Meteo's own `et0_fao_evapotranspiration`, the same FAO-56 Penman-Monteith
/// reference evapotranspiration `WateringRuleEngine.estimateET0` computes by hand. Used only
/// as a cross-check logged alongside the rule engine's own value, never to replace or feed
/// into the actual watering calculation — see
/// docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md section 9.1 for why: the hand-rolled
/// implementation already had one silent unit/magnitude bug (`reserveDepthPerCm`), and a
/// formula with no external reference to check against can have another one that compiles
/// fine and looks plausible. Free, keyless, no rate limit that a single-user app could hit.
protocol ET0ReferenceProviding: Sendable {
    func fetchReferenceET0(latitude: Double, longitude: Double) async throws -> Double
}

struct OpenMeteoET0Provider: ET0ReferenceProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchReferenceET0(latitude: Double, longitude: Double) async throws -> Double {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "et0_fao_evapotranspiration"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { throw OpenMeteoET0Error.invalidURL }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(OpenMeteoET0Response.self, from: data)
        guard let value = decoded.daily.et0FaoEvapotranspiration.first else {
            throw OpenMeteoET0Error.noData
        }
        return value
    }
}

enum OpenMeteoET0Error: Error {
    case invalidURL
    case noData
}

struct OpenMeteoET0Response: Decodable {
    struct Daily: Decodable {
        let et0FaoEvapotranspiration: [Double]

        enum CodingKeys: String, CodingKey {
            case et0FaoEvapotranspiration = "et0_fao_evapotranspiration"
        }
    }

    let daily: Daily
}
