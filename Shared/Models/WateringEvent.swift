import Foundation
import SwiftData

/// A single watering, logged by the user with one tap (P3). `source` records how it was
/// logged, which matters for the widget and Siri paths in M11.
@Model
final class WateringEvent {
    var id: UUID = UUID()
    var wateredAt: Date = Date.now
    var notes: String?
    /// "app", "widget", "siri". Nil treated as "app" for events ported from before this existed.
    var source: String?
    /// How many ml the user actually applied, measured (e.g. with a marked watering can).
    /// Optional and separate from `notes` because it's a number the calibration math reads
    /// (see `WateringEventRepository.recalibrate`), not free text. Nil means "not measured",
    /// which is the common case and must not be treated as zero. See
    /// docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 5 for why this matters: without
    /// it, the engine has always assumed every watering fills the pot to full capacity.
    var appliedMl: Double?

    @Attribute(.externalStorage) var photoData: Data?

    var plant: Plant?

    init(
        id: UUID = UUID(),
        wateredAt: Date = .now,
        notes: String? = nil,
        source: String? = "app",
        appliedMl: Double? = nil,
        photoData: Data? = nil,
        plant: Plant? = nil
    ) {
        self.id = id
        self.wateredAt = wateredAt
        self.notes = notes
        self.source = source
        self.appliedMl = appliedMl
        self.photoData = photoData
        self.plant = plant
    }
}
