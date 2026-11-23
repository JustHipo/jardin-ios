import Foundation
import SwiftData

/// Local-only model, NOT synced to CloudKit — it is device configuration, not garden data.
/// This is the single source of truth `AppSettings` reads and writes. The old codebase had
/// this model AND 20 direct `UserDefaults.standard` calls that never consulted it; that
/// double source of truth is exactly what let pet safety depend on an untyped string key.
/// See docs/REPORTE_ESTADO_Y_REDISENO.md A1 and docs/ANALISIS_IMPLEMENTACION.md section 4.
@Model
final class UserSettings {
    var id: UUID = UUID()

    var cityName: String?
    var latitude: Double?
    var longitude: Double?

    var notificationsEnabled: Bool = true
    /// Hour of day (0-23) the daily digest notification fires.
    var dailyDigestHour: Int = 9

    // MARK: Pet safety — hard product requirement, never left ambiguous.

    var hasPets: Bool = false
    /// "dog", "cat", "both". Nil when `hasPets` is false.
    var petTypeRaw: String?

    var hasCompletedFirstLaunch: Bool = false
    var hasSeenTutorial: Bool = false

    init(
        id: UUID = UUID(),
        cityName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        notificationsEnabled: Bool = true,
        dailyDigestHour: Int = 9,
        hasPets: Bool = false,
        petTypeRaw: String? = nil,
        hasCompletedFirstLaunch: Bool = false,
        hasSeenTutorial: Bool = false
    ) {
        self.id = id
        self.cityName = cityName
        self.latitude = latitude
        self.longitude = longitude
        self.notificationsEnabled = notificationsEnabled
        self.dailyDigestHour = dailyDigestHour
        self.hasPets = hasPets
        self.petTypeRaw = petTypeRaw
        self.hasCompletedFirstLaunch = hasCompletedFirstLaunch
        self.hasSeenTutorial = hasSeenTutorial
    }
}

enum PetType: String, Sendable, CaseIterable, Codable {
    case dog, cat, both
}
