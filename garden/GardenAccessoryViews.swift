import SwiftUI
import WidgetKit

/// "Visible sin desbloquear el teléfono" (M11 mockup) — the two lock-screen faces. Both let
/// the system apply the lock screen's own vibrancy/tint, so no custom colors or backgrounds.
struct GardenAccessoryCircularView: View {
    let entry: GardenWidgetEntry

    var body: some View {
        let count = entry.overduePlants.count
        Gauge(value: min(Double(count), 5), in: 0...5) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text(count > 0 ? "\(count)" : "✓")
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.clear, for: .widget)
    }
}

struct GardenAccessoryRectangularView: View {
    let entry: GardenWidgetEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.fill")
            VStack(alignment: .leading, spacing: 0) {
                if entry.overduePlants.isEmpty {
                    if let next = entry.nextPlant {
                        Text("Próximo: \(next.subtitle)").font(.headline).lineLimit(1)
                        Text(next.name).font(.caption).lineLimit(1)
                    } else {
                        Text("Todo en orden").font(.headline)
                    }
                } else {
                    Text(entry.overduePlants.count == 1 ? "1 con sed" : "\(entry.overduePlants.count) con sed")
                        .font(.headline)
                    Text(entry.overduePlants.map(\.name).joined(separator: " y "))
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}
