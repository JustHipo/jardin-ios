import AppIntents
import SwiftUI
import WidgetKit

/// "El que resuelve el problema: se riega desde aquí" (M11 mockup) — the home-screen medium
/// face. Each overdue row is a tap-to-water button; when nothing is overdue it falls back to
/// the next plant due, never an empty state.
struct GardenMediumView: View {
    let entry: GardenWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if entry.overduePlants.isEmpty {
                if let next = entry.nextPlant {
                    row(next)
                } else {
                    Text("Añade tu primera planta desde la app")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            } else {
                ForEach(entry.overduePlants) { plant in
                    row(plant)
                }
                Spacer(minLength: 0)
                Text("Toca la gota para registrar el riego")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }

    private var header: some View {
        HStack {
            if entry.overduePlants.isEmpty {
                Label(
                    entry.nextPlant == nil ? "Todo en orden" : "Próximo riego",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.gardenBrand)
            } else {
                Label(
                    entry.overduePlants.count == 1 ? "1 planta con sed" : "\(entry.overduePlants.count) plantas con sed",
                    systemImage: "drop.fill"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.gardenOverdue)
            }
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.gardenBrand)
        }
    }

    private func row(_ plant: WidgetPlantInfo) -> some View {
        HStack(spacing: 8) {
            PlantThumbnail(plant: plant, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(plant.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(plant.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(plant.isOverdue ? Color.gardenOverdue : .secondary)
            }
            Spacer()
            Button(intent: WaterPlantIntent(plantId: plant.id.uuidString)) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.gardenBrand))
            }
            .buttonStyle(.plain)
        }
    }
}
