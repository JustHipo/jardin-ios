import Foundation
import SwiftData

protocol PlantRepositoryProtocol {
    func fetchAll() throws -> [Plant]
    func fetchById(_ id: UUID) throws -> Plant?
    func insert(_ plant: Plant) throws
    func delete(_ plant: Plant) throws
    func save() throws
}

struct PlantRepository: PlantRepositoryProtocol {
    let modelContext: ModelContext

    func fetchAll() throws -> [Plant] {
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> Plant? {
        let descriptor = FetchDescriptor<Plant>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    func insert(_ plant: Plant) throws {
        modelContext.insert(plant)
        try modelContext.save()
    }

    func delete(_ plant: Plant) throws {
        modelContext.delete(plant)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }
}
