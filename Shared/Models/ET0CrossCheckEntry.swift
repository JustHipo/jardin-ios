import Foundation
import SwiftData

/// One comparison between our own hand-rolled Penman-Monteith ET0 and Open-Meteo's reference
/// value for the same day and place. Persisted, not just logged to `os.Logger`, precisely
/// because the point of this cross-check is to notice a SYSTEMATIC bias over weeks, and
/// os_log is not a place either of us can casually come back to and ask "is this always the
/// same direction, or was that one day noise?". See
/// docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md section 9.1 and `BASELINE_ALGORITMO_RIEGO.md`
/// section 3, where the first-ever real comparison already found a 38% gap.
@Model
final class ET0CrossCheckEntry {
    var id: UUID = UUID()
    var occurredAt: Date = Date.now

    var ownEt0MmPerDay: Double = 0
    var referenceEt0MmPerDay: Double = 0
    /// `(own - reference) / reference * 100`. Positive means we overestimate ET0 (predict a
    /// shorter watering cycle than the reference would).
    var deltaPct: Double = 0

    var plant: Plant?

    init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        ownEt0MmPerDay: Double,
        referenceEt0MmPerDay: Double,
        deltaPct: Double,
        plant: Plant? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.ownEt0MmPerDay = ownEt0MmPerDay
        self.referenceEt0MmPerDay = referenceEt0MmPerDay
        self.deltaPct = deltaPct
        self.plant = plant
    }
}
