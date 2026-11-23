import SwiftUI
import WidgetKit

struct GardenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GardenWidgetKind.identifier, provider: GardenTimelineProvider()) { entry in
            GardenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Riego")
        .description("Tus plantas con sed, y cuándo toca la próxima.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct GardenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GardenWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            GardenSmallView(entry: entry)
        case .accessoryCircular:
            GardenAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            GardenAccessoryRectangularView(entry: entry)
        default:
            GardenMediumView(entry: entry)
        }
    }
}

#Preview("Mediano, con sed", as: .systemMedium) {
    GardenWidget()
} timeline: {
    GardenWidgetEntry(date: .now, overduePlants: [], nextPlant: nil)
}
