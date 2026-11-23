import Foundation

/// Neutral weather models, independent of any specific provider. Field names deliberately
/// match what `Prompts.snapshotDict` already serializes into the AI context JSON — see
/// docs/ANALISIS_IMPLEMENTACION.md section 4: changing this shape changes the prompt without
/// meaning to, and the prompt is one of the pieces the design explicitly preserves whole.
nonisolated struct WeatherSnapshot: Codable, Sendable {
    let date: String
    let tempC: Double
    let tempMinC: Double?
    let tempMaxC: Double?
    let humidity: Int
    let uvIndex: Int
    let windKph: Double
    let description: String
    let rainMm: Double
    let cloudPct: Int
}

nonisolated struct WeatherContext: Sendable {
    let current: WeatherSnapshot
    let history: [WeatherSnapshot]
    let forecast: [WeatherSnapshot]
    let season: String
    let cityName: String
}
