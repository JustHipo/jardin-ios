import Foundation
import SwiftData

@Model
final class PlantPhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var photoData: Data?
    var capturedAt: Date = Date.now
    /// "watering", "analysis", "reference", "manual", "health_check"
    var context: String = "manual"

    var plant: Plant?

    init(
        id: UUID = UUID(),
        photoData: Data? = nil,
        capturedAt: Date = .now,
        context: String = "manual",
        plant: Plant? = nil
    ) {
        self.id = id
        self.photoData = photoData
        self.capturedAt = capturedAt
        self.context = context
        self.plant = plant
    }
}
