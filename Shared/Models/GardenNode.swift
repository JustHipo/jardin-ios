import Foundation
import SwiftData

/// A plant's position within a `GardenTab`. See `GardenTab` for why this is ported unused.
@Model
final class GardenNode {
    var id: UUID = UUID()
    var xPct: Double = 0
    var yPct: Double = 0
    var lightExposure: String?

    var plant: Plant?
    var gardenTab: GardenTab?

    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        xPct: Double,
        yPct: Double,
        lightExposure: String? = nil,
        plant: Plant? = nil,
        gardenTab: GardenTab? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.xPct = xPct
        self.yPct = yPct
        self.lightExposure = lightExposure
        self.plant = plant
        self.gardenTab = gardenTab
        self.createdAt = createdAt
    }
}
