import Foundation
import os
import WeatherKit
import CoreLocation

/// WeatherKit-backed provider. Replaces the old `WeatherAPIService`, removing the fourth API
/// key: WeatherKit ships with the developer account and needs no user-supplied credential.
///
/// Requires the owner to enable the WeatherKit capability on the App ID and add the entitlement
/// (see docs/ANALISIS_IMPLEMENTACION.md section 7, pending item 2). Until that is done, calls
/// fail with `WeatherError.providerFailed` rather than crashing — the app is expected to
/// degrade gracefully when weather is unavailable, same as it already does without Trefle.
///
/// NOTE: Apple's attribution requirement (Apple Weather mark + legal link to data sources)
/// is not optional when WeatherKit data is displayed. Space for it is reserved in the Ajustes
/// screen footer (M10) and should be added wherever raw weather figures are shown.
final class WeatherKitProvider: WeatherProviding {
    private let service = WeatherService.shared

    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherContext {
        let location = CLLocation(latitude: latitude, longitude: longitude)

        do {
            async let currentTask = service.weather(for: location, including: .current)
            async let dailyTask = service.weather(for: location, including: .daily)

            let (current, daily) = try await (currentTask, dailyTask)

            let currentSnapshot = WeatherSnapshot(
                date: Self.dateFormatter.string(from: current.date),
                tempC: current.temperature.converted(to: .celsius).value,
                tempMinC: nil,
                tempMaxC: nil,
                humidity: Int((current.humidity * 100).rounded()),
                uvIndex: current.uvIndex.value,
                windKph: current.wind.speed.converted(to: .kilometersPerHour).value,
                description: current.condition.description,
                // precipitationIntensity is a Measurement<UnitSpeed>; convert m/s to mm/h.
                rainMm: current.precipitationIntensity.converted(to: .metersPerSecond).value * 3_600 * 1_000,
                cloudPct: Int((current.cloudCover * 100).rounded())
            )

            // Forecast: next 3 days from the daily forecast.
            let forecastSnapshots = daily.forecast.prefix(3).map { day in
                WeatherSnapshot(
                    date: Self.dateFormatter.string(from: day.date),
                    tempC: (day.highTemperature.converted(to: .celsius).value
                        + day.lowTemperature.converted(to: .celsius).value) / 2,
                    tempMinC: day.lowTemperature.converted(to: .celsius).value,
                    tempMaxC: day.highTemperature.converted(to: .celsius).value,
                    humidity: Int((day.precipitationChance * 100).rounded()),
                    uvIndex: day.uvIndex.value,
                    windKph: day.wind.speed.converted(to: .kilometersPerHour).value,
                    description: day.condition.description,
                    rainMm: day.precipitationAmount.converted(to: .millimeters).value,
                    cloudPct: 0
                )
            }

            let isNorthern = latitude >= 0
            let season = Date.now.seasonForHemisphere(isNorthern: isNorthern)
            let cityName = await Self.reverseGeocodeCityName(location) ?? ""

            return WeatherContext(
                current: currentSnapshot,
                // History comes from WeatherCache's own rolling log, not from a live call —
                // WeatherKit's historical query has different limits and this app only needs
                // a handful of days it already observed while running.
                history: [],
                forecast: Array(forecastSnapshots),
                season: season,
                cityName: cityName
            )
        } catch {
            AppLog.weather.error("WeatherKit fetch failed: \(error, privacy: .public)")
            throw WeatherError.providerFailed(underlying: String(describing: error))
        }
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private static func reverseGeocodeCityName(_ location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let place = placemarks.first else { return nil }
        return place.locality ?? place.administrativeArea ?? place.country
    }
}
