import Testing
@testable import newGardenNew

/// The per-plant learning signal proposed in docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md
/// section 11: a single scalar, nudged by real watering dates, never by a photo or an AI
/// inference. Pure function, same testing philosophy as `WateringRuleEngineTests`.
struct WateringCalibrationTests {

    @Test("Watering exactly on schedule leaves the multiplier unchanged")
    func onScheduleStaysNeutral() {
        let updated = WateringCalibration.updatedMultiplier(
            previousMultiplier: 1.0, predictedCycleDays: 7, actualIntervalDays: 7
        )
        #expect(abs(updated - 1.0) < 0.0001)
    }

    @Test("Watering earlier than predicted lowers the multiplier")
    func earlyWateringLowersMultiplier() {
        let updated = WateringCalibration.updatedMultiplier(
            previousMultiplier: 1.0, predictedCycleDays: 10, actualIntervalDays: 5
        )
        #expect(updated < 1.0)
    }

    @Test("Watering later than predicted raises the multiplier")
    func lateWateringRaisesMultiplier() {
        let updated = WateringCalibration.updatedMultiplier(
            previousMultiplier: 1.0, predictedCycleDays: 10, actualIntervalDays: 20
        )
        #expect(updated > 1.0)
    }

    @Test("One outlier watering moves the multiplier by a bounded amount, not to the raw ratio")
    func oneOutlierIsSmoothed() {
        // Ratio here is 0.1 (watered at day 1 of a predicted 10-day cycle), but the multiplier
        // should only move part way there, not collapse to 0.1 from a single data point.
        let updated = WateringCalibration.updatedMultiplier(
            previousMultiplier: 1.0, predictedCycleDays: 10, actualIntervalDays: 1
        )
        #expect(updated > 0.5)
        #expect(updated < 1.0)
    }

    @Test("The multiplier never leaves its sane range even after repeated extreme observations")
    func staysWithinBounds() {
        var multiplier = WateringCalibration.neutral
        for _ in 0..<50 {
            multiplier = WateringCalibration.updatedMultiplier(
                previousMultiplier: multiplier, predictedCycleDays: 30, actualIntervalDays: 1
            )
        }
        #expect(multiplier >= WateringCalibration.minMultiplier)

        multiplier = WateringCalibration.neutral
        for _ in 0..<50 {
            multiplier = WateringCalibration.updatedMultiplier(
                previousMultiplier: multiplier, predictedCycleDays: 1, actualIntervalDays: 60
            )
        }
        #expect(multiplier <= WateringCalibration.maxMultiplier)
    }

    @Test("Invalid inputs (zero or negative days) leave the multiplier untouched")
    func invalidInputsAreIgnored() {
        let updated = WateringCalibration.updatedMultiplier(
            previousMultiplier: 0.8, predictedCycleDays: 0, actualIntervalDays: 5
        )
        #expect(updated == 0.8)
    }

    @Test("Applying the multiplier scales the cycle and stays within the engine's own clamp")
    func applyMultiplierScalesAndClamps() {
        #expect(WateringCalibration.applyMultiplier(0.5, toCycleDays: 10) == 5)
        #expect(WateringCalibration.applyMultiplier(2.0, toCycleDays: 40) == WateringRuleEngine.maxCycleDays)
        #expect(WateringCalibration.applyMultiplier(0.1, toCycleDays: 2) == WateringRuleEngine.minCycleDays)
    }

    // MARK: - Leaching fraction / applied ml (docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 5)

    @Test("Retained water is applied water minus the leaching fraction")
    func retainedMlAppliesLeachingFraction() {
        let retained = WateringCalibration.retainedMl(appliedMl: 500, leachingFraction: 0.2)
        #expect(abs(retained - 400) < 0.001)
    }

    @Test("Fill fraction is 1.0 when the retained water exactly matches pot capacity")
    func fillFractionAtExactCapacity() {
        // 500ml applied, 15% default leaching -> 425ml retained -> 0.425L.
        let fraction = WateringCalibration.fillFraction(appliedMl: 500, potCapacityLiters: 0.425)
        #expect(fraction != nil)
        #expect(abs((fraction ?? 0) - 1.0) < 0.001)
    }

    @Test("Fill fraction below capacity is proportionally less than 1.0")
    func fillFractionBelowCapacity() {
        let fraction = WateringCalibration.fillFraction(appliedMl: 250, potCapacityLiters: 1.0, leachingFraction: 0)
        #expect(abs((fraction ?? 0) - 0.25) < 0.001)
    }

    @Test("Fill fraction is nil when pot capacity isn't known")
    func fillFractionNilWithoutCapacity() {
        #expect(WateringCalibration.fillFraction(appliedMl: 300, potCapacityLiters: 0) == nil)
    }

    @Test("A partially filled previous watering makes a short real interval read as on-target, not as model error")
    func partialFillAdjustsExpectedInterval() {
        // Predicted cycle is 10 days assuming a FULL reserve. The previous watering only
        // filled the pot to 50%, so watering again after 5 days is exactly on target for that
        // half-full reserve — the multiplier should barely move, not read this as "the model
        // overestimates by 2x" the way it would without knowing the fill fraction.
        let withoutFillInfo = WateringCalibration.updatedMultiplier(
            previousMultiplier: 1.0, predictedCycleDays: 10, actualIntervalDays: 5
        )
        let withFillInfo = WateringCalibration.updatedMultiplier(
            previousMultiplier: 1.0, predictedCycleDays: 10, actualIntervalDays: 5, fillFraction: 0.5
        )
        #expect(abs(withFillInfo - 1.0) < 0.01) // ratio is ~5/(10*0.5) = 1.0, no real correction needed
        #expect(withFillInfo > withoutFillInfo) // the uninformed version wrongly pushes the multiplier down
    }
}
