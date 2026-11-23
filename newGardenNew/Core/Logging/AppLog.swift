import Foundation
import os

/// Structured logging for the whole app.
///
/// Replaces the 59 loose `print()` calls of the previous codebase. `print` writes to the
/// system log with no level, no category and no way to redact, which is unacceptable for
/// anything that carries API responses or user data.
///
/// Use `privacy: .private` for anything derived from user content. Values interpolated into
/// an `os.Logger` message are private by default; the explicit annotation is kept where the
/// intent matters.
nonisolated enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.ipo.newGardenNew"

    /// App lifecycle, dependency wiring, scene phase.
    static let app = Logger(subsystem: subsystem, category: "app")

    /// SwiftData container, fetches, saves and migrations.
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// Species identification, disease detection, botanical lookups.
    static let plantData = Logger(subsystem: subsystem, category: "plantData")

    /// Weather fetching and caching.
    static let weather = Logger(subsystem: subsystem, category: "weather")

    /// The AI engine and its routing decisions.
    static let ai = Logger(subsystem: subsystem, category: "ai")

    /// Watering analysis and the background refresh task.
    static let watering = Logger(subsystem: subsystem, category: "watering")

    /// Local notification scheduling.
    static let notifications = Logger(subsystem: subsystem, category: "notifications")

    /// Settings reads and writes.
    static let settings = Logger(subsystem: subsystem, category: "settings")

    /// Deliberately narrated user-flow milestones (permission requested, plant saved, sheet
    /// dismissed, view reappeared and reloaded). Not a replacement for the categories above —
    /// this one exists so a checkpoint testing session can filter to `category:checkpoint`
    /// and read a clean, ordered narrative of what the app actually did, independent of the
    /// low-level noise everything else produces.
    static let checkpoint = Logger(subsystem: subsystem, category: "checkpoint")
}
