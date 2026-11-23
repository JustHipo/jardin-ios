import Foundation
import SwiftData

protocol AIAuditRepositoryProtocol {
    func fetchAll(limit: Int) throws -> [AIAuditEntry]
    func fetchForPlant(_ plant: Plant) throws -> [AIAuditEntry]
}

struct AIAuditRepository: AIAuditRepositoryProtocol {
    let modelContext: ModelContext

    func fetchAll(limit: Int = 100) throws -> [AIAuditEntry] {
        var descriptor = FetchDescriptor<AIAuditEntry>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func fetchForPlant(_ plant: Plant) throws -> [AIAuditEntry] {
        let plantId = plant.id
        let descriptor = FetchDescriptor<AIAuditEntry>(
            predicate: #Predicate { $0.plant?.id == plantId },
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
