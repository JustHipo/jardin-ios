import Foundation
import SwiftData

/// One real watering folded into a plant's calibration multiplier — a durable history of
/// `WateringCalibration.updatedMultiplier`, not just the running scalar on `Plant`. Exists so
/// the dashboard (Features/Dashboard) can show "esto es lo que fue pasando", not only "esto es
/// lo que hay ahora". See docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md section 11 and
/// `WateringEventRepository.recalibrate`.
@Model
final class WateringCalibrationEvent {
    var id: UUID = UUID()
    var occurredAt: Date = Date.now

    var previousMultiplier: Double = 1.0
    var updatedMultiplier: Double = 1.0
    var predictedCycleDays: Int = 0
    var actualIntervalDays: Int = 0
    /// The ml the user measured for the PREVIOUS watering (the one that started this
    /// interval), when they logged it. Nil is the common case ("not measured"), in which case
    /// `fillFraction` is also nil and the multiplier update assumed a full reserve, same as
    /// before this existed. See docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 5.
    var appliedMl: Double?
    /// How full that previous watering actually left the reserve (1.0 = full), when
    /// computable — see `WateringCalibration.fillFraction(appliedMl:potCapacityLiters:)`.
    var fillFraction: Double?

    var plant: Plant?

    init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        previousMultiplier: Double,
        updatedMultiplier: Double,
        predictedCycleDays: Int,
        actualIntervalDays: Int,
        appliedMl: Double? = nil,
        fillFraction: Double? = nil,
        plant: Plant? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.previousMultiplier = previousMultiplier
        self.updatedMultiplier = updatedMultiplier
        self.predictedCycleDays = predictedCycleDays
        self.actualIntervalDays = actualIntervalDays
        self.appliedMl = appliedMl
        self.fillFraction = fillFraction
        self.plant = plant
    }
}
