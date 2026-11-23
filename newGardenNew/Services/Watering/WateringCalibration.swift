import Foundation

/// Per-plant calibration learned purely from real watering dates, never from photos or AI
/// inference. Closes the gap every external review of the algorithm converged on
/// independently: the deterministic engine's weakest term is the size and properties of the
/// "reserve" it's modeling, not the weather math on top of it. Instead of trying to model
/// substrate/pot volume more precisely, this absorbs whatever error is actually in that
/// reserve estimate for one specific plant, from what the user really does.
///
/// Deliberately not a Kalman filter or a Bayesian update: the goal is only to predict when to
/// water this plant next, not to explain why the reserve is what it is, so a single scalar
/// nudged by an exponential moving average is enough. See
/// docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md sections 7 and 11.
enum WateringCalibration {
    static let neutral: Double = 1.0
    static let minMultiplier: Double = 0.5
    static let maxMultiplier: Double = 2.0

    /// How much weight the newest observation gets against the running multiplier. Low on
    /// purpose: one unusual watering (a trip, a forgotten plant, a one-off deep clean) should
    /// nudge the estimate, not overwrite months of prior signal.
    private static let smoothing: Double = 0.25

    /// Standard nursery-industry leaching fraction for gravity/overhead watering (a user
    /// pouring from a watering can until it drains a little), per
    /// docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 5: 10-15% is the typical target
    /// for this watering method (higher, 25-30%, is for drip/micro-irrigation, not relevant
    /// here). Used only when the user has logged real ml applied.
    static let defaultLeachingFraction: Double = 0.15

    /// Converts water actually applied (ml) into water actually retained in the substrate —
    /// the rest drains out the bottom. `retenida = aplicada × (1 − LF)` is the standard
    /// operating model across the container-nursery literature reviewed, not a guess; see
    /// docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 5.2.
    static func retainedMl(appliedMl: Double, leachingFraction: Double = defaultLeachingFraction) -> Double {
        appliedMl * (1 - leachingFraction)
    }

    /// How much of the pot's full capacity one watering actually restored: 1.0 means "filled
    /// to capacity", 0.5 means "only half of what the reserve can hold". Needs the pot's real
    /// capacity in liters (`WateringRuleEngine.frustumVolumeLiters(...) * substrate AWC`) —
    /// nil when that isn't known, since guessing a fraction without a real capacity to compare
    /// against would be worse than not having the number at all. Clamped to 1.5: a heavier
    /// pour than the pot needs is physically possible, but shouldn't be read past a modest
    /// margin as literal fact.
    static func fillFraction(appliedMl: Double, potCapacityLiters: Double, leachingFraction: Double = defaultLeachingFraction) -> Double? {
        guard potCapacityLiters > 0 else { return nil }
        let retainedLiters = retainedMl(appliedMl: appliedMl, leachingFraction: leachingFraction) / 1000
        return min(1.5, max(0, retainedLiters / potCapacityLiters))
    }

    /// Folds one real watering interval into the running multiplier for a plant.
    ///
    /// - Parameters:
    ///   - previousMultiplier: The plant's multiplier before this watering.
    ///   - predictedCycleDays: What the deterministic engine was predicting for this plant
    ///     right before the user watered (`Plant.effectiveCycleDays` at that moment).
    ///   - actualIntervalDays: Calendar days since the previous real watering.
    ///   - fillFraction: How full the PREVIOUS watering actually left the reserve (see
    ///     `fillFraction(appliedMl:potCapacityLiters:)`), when known. Without this, a shorter
    ///     real interval always reads as "the model overestimates the cycle" — but if the
    ///     previous watering only half-filled the pot, a shorter interval is just physically
    ///     correct and shouldn't be blamed on the ET/Kc model. Nil (the common case, when ml
    ///     wasn't measured) means "assume that watering filled the reserve", the same
    ///     assumption the engine already makes everywhere else.
    /// - Returns: The updated multiplier, clamped to `[minMultiplier, maxMultiplier]` so one
    ///   outlier (a missed notification, a plant given away and back) can't send a future
    ///   prediction to 1 day or 60 days on its own.
    static func updatedMultiplier(
        previousMultiplier: Double,
        predictedCycleDays: Int,
        actualIntervalDays: Int,
        fillFraction: Double? = nil
    ) -> Double {
        guard predictedCycleDays > 0, actualIntervalDays > 0 else { return previousMultiplier }
        let effectiveFill = fillFraction ?? 1.0
        guard effectiveFill > 0 else { return previousMultiplier }
        let adjustedPredictedDays = Double(predictedCycleDays) * effectiveFill
        guard adjustedPredictedDays > 0 else { return previousMultiplier }
        let ratio = Double(actualIntervalDays) / adjustedPredictedDays
        let blended = previousMultiplier * (1 - smoothing) + ratio * smoothing
        return min(maxMultiplier, max(minMultiplier, blended))
    }

    /// Applies a plant's learned multiplier on top of the rule engine's own cycle length,
    /// clamped to the same sane range the engine itself uses.
    static func applyMultiplier(_ multiplier: Double, toCycleDays cycleDays: Int) -> Int {
        let scaled = Double(cycleDays) * multiplier
        return min(WateringRuleEngine.maxCycleDays, max(WateringRuleEngine.minCycleDays, Int(scaled.rounded())))
    }
}
