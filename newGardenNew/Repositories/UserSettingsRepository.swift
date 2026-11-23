import Foundation
import SwiftData

/// Repositories are MainActor-isolated by default (see `SWIFT_DEFAULT_ACTOR_ISOLATION` in the
/// project build settings) since `ModelContext` itself is not `Sendable`. This matches Swift
/// 6.2's Approachable Concurrency default: most of this app's code is single-threaded by
/// design, and only network-facing services cross actors explicitly.
protocol UserSettingsRepositoryProtocol {
    func fetch() throws -> UserSettings
    func save() throws
}

struct UserSettingsRepository: UserSettingsRepositoryProtocol {
    let modelContext: ModelContext

    func fetch() throws -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        let settings = UserSettings()
        modelContext.insert(settings)
        try modelContext.save()
        return settings
    }

    func save() throws {
        try modelContext.save()
    }
}
