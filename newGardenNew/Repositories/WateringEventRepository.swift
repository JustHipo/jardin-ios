import Foundation
import SwiftData

protocol WateringEventRepositoryProtocol {
    func fetchForPlant(_ plant: Plant) throws -> [WateringEvent]
    func insert(_ event: WateringEvent) throws
    func delete(_ event: WateringEvent) throws
    func save() throws
}

struct WateringEventRepository: WateringEventRepositoryProtocol {
    let modelContext: ModelContext

    func fetchForPlant(_ plant: Plant) throws -> [WateringEvent] {
        let plantId = plant.id
        let descriptor = FetchDescriptor<WateringEvent>(
            predicate: #Predicate { $0.plant?.id == plantId },
            sortBy: [SortDescriptor(\.wateredAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func insert(_ event: WateringEvent) throws {
        if let plant = event.plant {
            recalibrate(plant: plant, newEvent: event)
        }
        modelContext.insert(event)
        try modelContext.save()
    }

    /// Folds one real watering into the plant's calibration multiplier — see
    /// `WateringCalibration` and docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md section 11.
    /// Silent by design: this is a background learning signal, not something the user needs
    /// to be told is happening on every tap of "regué esta planta".
    ///
    /// Excludes `newEvent` from the "previous waterings" query by id, not just by calling this
    /// before `modelContext.insert(event)`: assigning `plant:` in `WateringEvent.init` already
    /// links it into the relationship graph of an already-tracked `Plant`, so a fetch can
    /// surface the not-yet-inserted event as its own "most recent watering" and compare it
    /// against itself (a zero-day interval that silently no-ops via the guard below) — found
    /// while writing this repository's own tests, not in a bug report.
    private func recalibrate(plant: Plant, newEvent: WateringEvent) {
        let plantId = plant.id
        let newEventId = newEvent.id
        let descriptor = FetchDescriptor<WateringEvent>(
            predicate: #Predicate { $0.plant?.id == plantId && $0.id != newEventId },
            sortBy: [SortDescriptor(\.wateredAt, order: .reverse)]
        )
        guard let previousEvent = (try? modelContext.fetch(descriptor))?.first else { return }
        let actualIntervalDays = newEvent.wateredAt.calendarDaysSince(previousEvent.wateredAt)
        guard actualIntervalDays > 0 else { return }
        let predictedCycleDays = plant.effectiveCycleDays
        let previousMultiplier = plant.waterCalibrationMultiplier

        // If the PREVIOUS watering (the one that started this interval) had a measured ml
        // amount, and this plant's real pot capacity is known, figure out how full that
        // watering actually left the reserve — a shorter-than-predicted interval is expected,
        // not a model error, if the pot was only half filled. See
        // docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 5 and `WateringCalibration`.
        let fillFraction = previousEvent.appliedMl.flatMap { appliedMl in
            potCapacityLiters(for: plant).flatMap { capacity in
                WateringCalibration.fillFraction(appliedMl: appliedMl, potCapacityLiters: capacity)
            }
        }

        let updatedMultiplier = WateringCalibration.updatedMultiplier(
            previousMultiplier: previousMultiplier,
            predictedCycleDays: predictedCycleDays,
            actualIntervalDays: actualIntervalDays,
            fillFraction: fillFraction
        )
        plant.waterCalibrationMultiplier = updatedMultiplier
        // History, not just the running scalar — the Dashboard tab (Features/Dashboard) reads
        // this to show how a plant's calibration actually moved over time, not just where it
        // landed. `newEvent.wateredAt` (not `.now`) so a watering logged late still lands in
        // the history at the date it really happened.
        modelContext.insert(WateringCalibrationEvent(
            occurredAt: newEvent.wateredAt,
            previousMultiplier: previousMultiplier,
            updatedMultiplier: updatedMultiplier,
            predictedCycleDays: predictedCycleDays,
            actualIntervalDays: actualIntervalDays,
            appliedMl: previousEvent.appliedMl,
            fillFraction: fillFraction,
            plant: plant
        ))
    }

    /// The pot's real available-water capacity in liters, from measured geometry and
    /// substrate — nil when either isn't known, same "don't guess a number you don't have"
    /// rule as everywhere else in this file. See `WateringRuleEngine.frustumVolumeLiters`.
    private func potCapacityLiters(for plant: Plant) -> Double? {
        guard let top = plant.containerTopDiameterCm, let bottom = plant.containerBottomDiameterCm,
              let height = plant.containerHeightCm, top > 0, height > 0 else { return nil }
        let awc = plant.substrateType?.availableWaterCapacity ?? WateringRuleEngine.Input.defaultAvailableWaterCapacity
        return WateringRuleEngine.frustumVolumeLiters(topDiameterCm: top, bottomDiameterCm: bottom, heightCm: height) * awc
    }

    func delete(_ event: WateringEvent) throws {
        modelContext.delete(event)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }
}
