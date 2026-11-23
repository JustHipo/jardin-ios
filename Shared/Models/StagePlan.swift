import Foundation
import SwiftData

/// One stage of a seed-grown plant's care plan (M08). A `Plant` being grown from seed has
/// one `StagePlan` per `GrowthStage` it has gone through or will go through.
///
/// All properties optional per CloudKit's requirements, agreed with the design session:
/// the exact detail of M08 is not finalized, so this stays minimal and additive.
@Model
final class StagePlan {
    var id: UUID = UUID()
    var stageRaw: String?
    var startDay: Int?
    var endDay: Int?
    var wateringIntervalHours: Int?
    var note: String?

    var plant: Plant?

    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        stage: GrowthStage? = nil,
        startDay: Int? = nil,
        endDay: Int? = nil,
        wateringIntervalHours: Int? = nil,
        note: String? = nil,
        plant: Plant? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.stageRaw = stage?.rawValue
        self.startDay = startDay
        self.endDay = endDay
        self.wateringIntervalHours = wateringIntervalHours
        self.note = note
        self.plant = plant
        self.createdAt = createdAt
    }

    var stage: GrowthStage? {
        get { stageRaw.flatMap(GrowthStage.init(rawValue:)) }
        set { stageRaw = newValue?.rawValue }
    }
}
