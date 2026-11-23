import Foundation
import os
import CoreLocation
import Observation

/// Detects and remembers the user's location for weather. Reads/writes go through
/// `AppSettings`, not `UserDefaults` directly — see the A1 finding this app fixes.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let settings: AppSettings

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLoading = false

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        AppLog.checkpoint.notice("Location: requestPermission() called, current status \(self.authorizationStatus.rawValue, privacy: .public)")
        manager.requestWhenInUseAuthorization()
    }

    func detectLocation() {
        isLoading = true
        manager.requestLocation()
    }

    func setManualLocation(city: String, lat: Double, lon: Double) {
        settings.cityName = city
        settings.latitude = lat
        settings.longitude = lon
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.isLoading = false
            self.settings.latitude = location.coordinate.latitude
            self.settings.longitude = location.coordinate.longitude
            await self.reverseGeocode(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            AppLog.app.error("Location update failed: \(error, privacy: .public)")
            self.isLoading = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            AppLog.checkpoint.notice("Location: authorization changed to \(status.rawValue, privacy: .public) (0=notDetermined 2=denied 3=authorizedAlways 4=whenInUse)")
            if status == .authorizedWhenInUse {
                self.detectLocation()
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async {
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
           let place = placemarks.first {
            settings.cityName = place.locality ?? place.administrativeArea ?? place.country
            AppLog.checkpoint.notice("Location: resolved city name, weather can now use a real location")
        } else {
            AppLog.checkpoint.notice("Location: reverse geocode failed or returned no placemark")
        }
    }
}
