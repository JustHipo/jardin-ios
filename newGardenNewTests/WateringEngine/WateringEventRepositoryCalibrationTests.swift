import Testing
import Foundation
import SwiftData
@testable import newGardenNew

/// Verifies the actual wiring point, not just the pure math in `WateringCalibrationTests`:
/// that `WateringEventRepository.insert` looks at the PREVIOUS watering (not the one being
/// inserted) to compute the real elapsed interval, and writes the result onto the right plant.
struct WateringEventRepositoryCalibrationTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(GardenSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test("The first watering ever logged has nothing to compare against, so the multiplier stays neutral")
    func firstWateringStaysNeutral() throws {
        let context = try makeInMemoryContext()
        let plant = Plant(name: "Ficus", waterEveryDays: 10)
        context.insert(plant)
        let repository = WateringEventRepository(modelContext: context)

        try repository.insert(WateringEvent(wateredAt: .now, plant: plant))

        #expect(plant.waterCalibrationMultiplier == WateringCalibration.neutral)
    }

    @Test("Watering well before the predicted cycle lowers the plant's multiplier")
    func earlyRealWateringLowersMultiplier() throws {
        let context = try makeInMemoryContext()
        let plant = Plant(name: "Ficus", waterEveryDays: 10)
        context.insert(plant)
        let repository = WateringEventRepository(modelContext: context)

        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        try repository.insert(WateringEvent(wateredAt: fiveDaysAgo, plant: plant))
        // Predicted cycle at the time of the SECOND watering is still 10 days (unadjusted),
        // and the real interval between the two waterings is 5 days: watered twice as often
        // as predicted.
        try repository.insert(WateringEvent(wateredAt: .now, plant: plant))

        #expect(plant.waterCalibrationMultiplier < 1.0)
        #expect(plant.waterCalibrationMultiplier >= WateringCalibration.minMultiplier)
    }

    @Test("A partially filled previous watering (known ml, known geometry) keeps the multiplier near neutral instead of over-correcting")
    func partialFillWithRealGeometryAvoidsOverCorrection() throws {
        let context = try makeInMemoryContext()
        let plant = Plant(name: "Ficus", waterEveryDays: 10)
        plant.containerTopDiameterCm = 20
        plant.containerBottomDiameterCm = 20
        plant.containerHeightCm = 20
        plant.substrateType = .peat // AWC 0.30
        context.insert(plant)
        let repository = WateringEventRepository(modelContext: context)

        // Pot capacity: frustum(20,20,20) = 6.283L * 0.30 AWC = ~1.885L = 1885ml.
        // Applying only 942.5ml (half capacity, ignoring leaching for this round figure check)
        // should read as roughly a half-fill.
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        try repository.insert(WateringEvent(wateredAt: fiveDaysAgo, appliedMl: 942.5, plant: plant))
        try repository.insert(WateringEvent(wateredAt: .now, plant: plant))

        // Without fill-fraction awareness this would read as "watered twice as often as
        // predicted" and push the multiplier well below 1.0. With it, a 5-day interval on a
        // roughly-half-filled 10-day reserve is close to on-target.
        #expect(plant.waterCalibrationMultiplier > 0.9)
    }

    @Test("The calibration history records the applied ml and fill fraction when known")
    func calibrationHistoryRecordsAppliedMl() throws {
        let context = try makeInMemoryContext()
        let plant = Plant(name: "Ficus", waterEveryDays: 10)
        plant.containerTopDiameterCm = 20
        plant.containerBottomDiameterCm = 20
        plant.containerHeightCm = 20
        plant.substrateType = .peat
        context.insert(plant)
        let repository = WateringEventRepository(modelContext: context)

        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        try repository.insert(WateringEvent(wateredAt: fiveDaysAgo, appliedMl: 942.5, plant: plant))
        try repository.insert(WateringEvent(wateredAt: .now, plant: plant))

        let history = try context.fetch(FetchDescriptor<WateringCalibrationEvent>())
        #expect(history.count == 1)
        #expect(history.first?.appliedMl == 942.5)
        #expect(history.first?.fillFraction != nil)
    }
}
