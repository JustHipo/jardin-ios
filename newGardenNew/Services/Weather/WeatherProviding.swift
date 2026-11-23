import Foundation

/// Abstraction over the weather source, so the app can swap providers without touching
/// anything downstream (the water balance engine, the AI prompt builder, the UI).
///
/// Ported from the old `WeatherServiceProtocol`, renamed because "service" was used for
/// everything in the old codebase and told the reader nothing.
protocol WeatherProviding: Sendable {
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherContext
}

enum WeatherError: Error, LocalizedError, Sendable {
    case locationUnavailable
    case providerFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            String(localized: "weather.error.location", defaultValue: "No se pudo determinar tu ubicación.")
        case .providerFailed(let underlying):
            String(localized: "weather.error.provider", defaultValue: "No se pudo obtener el clima.") + " (\(underlying))"
        }
    }
}
