import Foundation
import os
import SwiftData
import Observation

/// The single source of truth for app configuration. Wraps the local-only `UserSettings`
/// SwiftData model with a typed, observable surface, so nothing in the app reads
/// `UserDefaults.standard` directly again.
///
/// Reads happen once at init from the model context; writes go straight back through
/// `UserSettingsRepository` so a save failure surfaces instead of disappearing.
@MainActor
@Observable
final class AppSettings {
    private let repository: any UserSettingsRepositoryProtocol
    private var model: UserSettings

    var cityName: String? {
        didSet { model.cityName = cityName; persist() }
    }
    var latitude: Double? {
        didSet { model.latitude = latitude; persist() }
    }
    var longitude: Double? {
        didSet { model.longitude = longitude; persist() }
    }
    var notificationsEnabled: Bool {
        didSet { model.notificationsEnabled = notificationsEnabled; persist() }
    }
    var dailyDigestHour: Int {
        didSet { model.dailyDigestHour = dailyDigestHour; persist() }
    }
    var hasPets: Bool {
        didSet { model.hasPets = hasPets; persist() }
    }
    var petType: PetType? {
        didSet { model.petTypeRaw = petType?.rawValue; persist() }
    }
    var hasCompletedFirstLaunch: Bool {
        didSet { model.hasCompletedFirstLaunch = hasCompletedFirstLaunch; persist() }
    }
    var hasSeenTutorial: Bool {
        didSet { model.hasSeenTutorial = hasSeenTutorial; persist() }
    }

    /// Last save error, if any. Surfaced so views can tell the user instead of the write
    /// disappearing silently, which is the M3 finding from the audit (`try? context.save()`).
    private(set) var lastSaveError: (any Error)?

    init(repository: any UserSettingsRepositoryProtocol) {
        self.repository = repository
        let loaded = (try? repository.fetch()) ?? UserSettings()
        self.model = loaded
        self.cityName = loaded.cityName
        self.latitude = loaded.latitude
        self.longitude = loaded.longitude
        self.notificationsEnabled = loaded.notificationsEnabled
        self.dailyDigestHour = loaded.dailyDigestHour
        self.hasPets = loaded.hasPets
        self.petType = loaded.petTypeRaw.flatMap(PetType.init(rawValue:))
        self.hasCompletedFirstLaunch = loaded.hasCompletedFirstLaunch
        self.hasSeenTutorial = loaded.hasSeenTutorial
    }

    private func persist() {
        do {
            try repository.save()
            lastSaveError = nil
        } catch {
            lastSaveError = error
            AppLog.settings.error("Failed to save settings: \(error, privacy: .public)")
        }
    }

    /// Has the location needed to fetch weather, whether manual or detected.
    var hasLocation: Bool { latitude != nil && longitude != nil }
}
