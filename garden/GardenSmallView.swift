import SwiftUI
import WidgetKit

/// "Para quien solo quiere el número" (M11 mockup) — no interaction, just the count.
struct GardenSmallView: View {
    let entry: GardenWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.overduePlants.isEmpty {
                emptyOrNext
            } else {
                Image(systemName: "drop.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.gardenOverdue)
                Spacer()
                Text("\(entry.overduePlants.count)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.gardenOverdue)
                Text("con sed")
                    .font(.system(size: 13, weight: .medium))
                Text(entry.overduePlants.map(\.name).joined(separator: ", "))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private var emptyOrNext: some View {
        if let next = entry.nextPlant {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.gardenBrand)
            Spacer()
            Text(next.subtitle)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.gardenBrand)
            Text("próximo riego")
                .font(.system(size: 13, weight: .medium))
            Text(next.name)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Image(systemName: "leaf.fill")
                .font(.system(size: 15))
                .foregroundStyle(Color.gardenBrand)
            Spacer()
            Text("Todo en orden")
                .font(.system(size: 13, weight: .medium))
        }
    }
}
