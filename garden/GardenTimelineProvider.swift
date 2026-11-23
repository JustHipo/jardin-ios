import SwiftData
import WidgetKit

struct GardenTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GardenWidgetEntry {
        GardenWidgetEntry(date: .now, overduePlants: [], nextPlant: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GardenWidgetEntry) -> Void) {
        completion(Self.makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GardenWidgetEntry>) -> Void) {
        let entry = Self.makeEntry()
        // The app itself reloads us right after a watering or a cycle recompute (see
        // `GardenWidgetKind`); this 30-minute fallback just keeps "hace X días" from going
        // stale if the app hasn't been opened in a while.
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private static func makeEntry() -> GardenWidgetEntry {
        let context = ModelContext(WidgetModelContainer.shared)
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        let plants = (try? context.fetch(descriptor)) ?? []

        let overdue = plants
            .filter { $0.wateringStatus == .overdue }
            .sorted { ($0.daysUntilDue ?? 0) < ($1.daysUntilDue ?? 0) }
            .prefix(3)
            .map(WidgetPlantInfo.init)

        if !overdue.isEmpty {
            return GardenWidgetEntry(date: .now, overduePlants: Array(overdue), nextPlant: nil)
        }

        // "Nunca queda vacío": nothing overdue, so show whichever watered plant is due next.
        let next = plants
            .filter { $0.lastWateredAt != nil }
            .min { ($0.daysUntilDue ?? .max) < ($1.daysUntilDue ?? .max) }
            .map(WidgetPlantInfo.init)

        return GardenWidgetEntry(date: .now, overduePlants: [], nextPlant: next)
    }
}
