import Foundation
import os

/// TEMPORARY stopgap. WeatherKit is the designed provider (see `WeatherKitProvider.swift`),
/// but it needs the owner to enable the capability on the App ID first (pending item 2,
/// docs/ANALISIS_IMPLEMENTACION.md section 7). Until that's done, WeatherKit calls fail every
/// time and the watering rule engine has no real weather data to compute against.
///
/// This wraps the WeatherAPI.com key recovered from the old app's Passwords entry (validated
/// live against the API on 2026-09-11) so the water balance can be tested end to end today.
///
/// Delete this file and switch `AppDependencies.weatherProvider` back to `WeatherKitProvider()`
/// once WeatherKit's capability is active — that's the only place this is wired in.
final class WeatherAPIProvider: WeatherProviding {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherContext {
        let urlString = "https://api.weatherapi.com/v1/forecast.json?key=\(apiKey)&q=\(latitude),\(longitude)&days=4&aqi=no&alerts=no"
        guard let url = URL(string: urlString) else {
            throw WeatherError.providerFailed(underlying: "invalid URL")
        }

        AppLog.checkpoint.notice("Weather: GET forecast for \(latitude, privacy: .public),\(longitude, privacy: .public)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(status) else {
                AppLog.checkpoint.notice("Weather: forecast -> HTTP \(status, privacy: .public)")
                throw WeatherError.providerFailed(underlying: "HTTP \(status)")
            }
            let decoded = try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
            let context = Self.map(decoded)
            AppLog.checkpoint.notice("Weather: forecast -> HTTP \(status, privacy: .public), city=\(context.cityName, privacy: .public) temp=\(context.current.tempC, privacy: .public)°C rain=\(context.current.rainMm, privacy: .public)mm")
            return context
        } catch let error as WeatherError {
            throw error
        } catch {
            AppLog.weather.error("WeatherAPI.com fetch failed: \(error, privacy: .public)")
            AppLog.checkpoint.notice("Weather: forecast FAILED — \(error, privacy: .public)")
            throw WeatherError.providerFailed(underlying: String(describing: error))
        }
    }

    private static func map(_ response: WeatherAPIResponse) -> WeatherContext {
        let current = WeatherSnapshot(
            date: response.location.localtime.prefix(10).description,
            tempC: response.current.temp_c,
            tempMinC: nil,
            tempMaxC: nil,
            humidity: response.current.humidity,
            uvIndex: Int(response.current.uv.rounded()),
            windKph: response.current.wind_kph,
            description: response.current.condition.text,
            rainMm: response.current.precip_mm,
            cloudPct: response.current.cloud
        )

        let forecast = (response.forecast?.forecastday ?? []).dropFirst().prefix(3).map { day in
            WeatherSnapshot(
                date: day.date,
                tempC: (day.day.maxtemp_c + day.day.mintemp_c) / 2,
                tempMinC: day.day.mintemp_c,
                tempMaxC: day.day.maxtemp_c,
                humidity: Int(day.day.avghumidity.rounded()),
                uvIndex: Int(day.day.uv.rounded()),
                windKph: 0,
                description: day.day.condition.text,
                rainMm: day.day.totalprecip_mm,
                cloudPct: 0
            )
        }

        let isNorthern = response.location.lat >= 0
        let season = Date.now.seasonForHemisphere(isNorthern: isNorthern)

        return WeatherContext(
            current: current,
            history: [],
            forecast: Array(forecast),
            season: season,
            cityName: response.location.name
        )
    }
}

// MARK: - WeatherAPI.com response shapes (kept private to this file, mapped to the neutral model above)

private struct WeatherAPIResponse: Codable {
    let location: Location
    let current: Current
    let forecast: Forecast?

    struct Location: Codable {
        let name: String
        let lat: Double
        let localtime: String
    }
    struct Current: Codable {
        let temp_c: Double
        let humidity: Int
        let wind_kph: Double
        let cloud: Int
        let uv: Double
        let precip_mm: Double
        let condition: Condition
    }
    struct Forecast: Codable {
        let forecastday: [ForecastDay]
    }
    struct ForecastDay: Codable {
        let date: String
        let day: Day
    }
    struct Day: Codable {
        let maxtemp_c: Double
        let mintemp_c: Double
        let avghumidity: Double
        let totalprecip_mm: Double
        let uv: Double
        let condition: Condition
    }
    struct Condition: Codable {
        let text: String
    }
}
