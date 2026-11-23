import Foundation
import SwiftData

protocol HealthCheckRepositoryProtocol {
    func fetchForPlant(_ plant: Plant) throws -> [HealthCheck]
    func insert(_ check: HealthCheck) throws
    func save() throws
}

struct HealthCheckRepository: HealthCheckRepositoryProtocol {
    let modelContext: ModelContext

    func fetchForPlant(_ plant: Plant) throws -> [HealthCheck] {
        let plantId = plant.id
        let descriptor = FetchDescriptor<HealthCheck>(
            predicate: #Predicate { $0.plant?.id == plantId },
            sortBy: [SortDescriptor(\.checkedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func insert(_ check: HealthCheck) throws {
        modelContext.insert(check)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }
}
