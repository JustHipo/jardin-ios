import Foundation
import SwiftData

/// The App Group both the app and the widget extension (`gardenExtension`) share. It is what
/// lets `WaterPlantIntent`, running in the extension's own process, write a real
/// `WateringEvent` into the SAME on-disk store the app reads — not a queued approximation.
/// Requires `com.apple.security.application-groups` on both targets' entitlements.
enum AppGroup {
    static let identifier = "group.com.ipo.newGardenNew"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            fatalError("App Group container unavailable — check the \(identifier) entitlement on both targets.")
        }
        return url
    }
}

/// Kept in one place, as agreed: reusing the owner's old CloudKit container versus starting fresh
/// is his call (docs/ANALISIS_IMPLEMENTACION.md section 7, pending item 5) — he confirmed
/// starting fresh without importing the old data, so this is a brand new container.
enum CloudKitConfig {
    static let containerIdentifier = "iCloud.com.ipo.newGardenNew"
}

/// The garden schema, shared between the app and the widget so both can open the exact same
/// store. Deliberately excludes `UserSettings`: that model is local-only device configuration
/// (see its own doc comment) and nothing outside the app ever needs it.
enum GardenSchema {
    static let models: [any PersistentModel.Type] = [
        Plant.self, GardenTab.self, GardenNode.self, WateringEvent.self,
        AIAnalysis.self, HealthCheck.self, AIAuditEntry.self, ChatMessage.self,
        CareStep.self, PlantPhoto.self, StagePlan.self,
        WateringCalibrationEvent.self, ET0CrossCheckEntry.self,
    ]

    /// Lives in the App Group container, not the app's own sandbox, so the widget extension
    /// (a separate process) can open the same physical file.
    static var storeURL: URL {
        AppGroup.containerURL.appending(path: "GardenData.sqlite")
    }
}
