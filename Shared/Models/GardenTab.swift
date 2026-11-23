import Foundation
import SwiftData

/// A spatial layout of plants over a background photo (the old "Jardín" tab). Not part of
/// the redesigned navigation — the owner left it commented out rather than deleted ("se conserva
/// para uso futuro"), so the model is ported but no view is built on top of it.
@Model
final class GardenTab {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var orientation: String = "portrait"

    @Attribute(.externalStorage) var backgroundPhotoData: Data?

    @Relationship(deleteRule: .cascade, inverse: \GardenNode.gardenTab)
    var nodes: [GardenNode]?

    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        orientation: String = "portrait",
        backgroundPhotoData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.orientation = orientation
        self.backgroundPhotoData = backgroundPhotoData
        self.createdAt = createdAt
    }
}
