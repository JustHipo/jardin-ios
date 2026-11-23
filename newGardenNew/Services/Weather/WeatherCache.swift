import Foundation

/// Actor-isolated cache with a 1 hour TTL and a 7 day rolling history, ported from the old
/// codebase (the design session called this "bien hecho" and it is: an actor is the right
/// tool for a single piece of mutable state shared across the app). Adapted to store the
/// neutral `WeatherSnapshot` instead of a WeatherAPI.com-shaped response.
actor WeatherCache {
    private var cached: WeatherContext?
    private var cachedAt: Date?
    private let cacheDuration: TimeInterval = 3600

    private var history: [WeatherSnapshot] = []
    private let historyLimit = 7

    var isCacheValid: Bool {
        guard let cachedAt else { return false }
        return Date.now.timeIntervalSince(cachedAt) < cacheDuration
    }

    func getCached() -> WeatherContext? {
        isCacheValid ? cached : nil
    }

    func store(_ context: WeatherContext) {
        cached = context
        cachedAt = .now
        appendToHistory(context.current)
    }

    /// Recent days observed, most recent last. Used to build the AI context's `history_3d`.
    func getHistory(days: Int = 3) -> [WeatherSnapshot] {
        Array(history.suffix(days))
    }

    private func appendToHistory(_ snapshot: WeatherSnapshot) {
        if history.last?.date == snapshot.date { return }
        history.append(snapshot)
        if history.count > historyLimit {
            history = Array(history.suffix(historyLimit))
        }
    }
}
