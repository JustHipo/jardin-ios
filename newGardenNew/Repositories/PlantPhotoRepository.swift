import Foundation
import SwiftData

protocol PlantPhotoRepositoryProtocol {
    func fetchForPlant(_ plant: Plant) throws -> [PlantPhoto]
    func insert(_ photo: PlantPhoto) throws
    func save() throws
}

struct PlantPhotoRepository: PlantPhotoRepositoryProtocol {
    let modelContext: ModelContext

    func fetchForPlant(_ plant: Plant) throws -> [PlantPhoto] {
        let plantId = plant.id
        let descriptor = FetchDescriptor<PlantPhoto>(
            predicate: #Predicate { $0.plant?.id == plantId },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func insert(_ photo: PlantPhoto) throws {
        modelContext.insert(photo)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }
}
