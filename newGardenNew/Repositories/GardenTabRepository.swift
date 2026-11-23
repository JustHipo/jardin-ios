import Foundation
import SwiftData

/// Ported unused — see `GardenTab`.
protocol GardenTabRepositoryProtocol {
    func fetchAll() throws -> [GardenTab]
    func insert(_ tab: GardenTab) throws
    func delete(_ tab: GardenTab) throws
    func save() throws
}

struct GardenTabRepository: GardenTabRepositoryProtocol {
    let modelContext: ModelContext

    func fetchAll() throws -> [GardenTab] {
        let descriptor = FetchDescriptor<GardenTab>(sortBy: [SortDescriptor(\.sortOrder)])
        return try modelContext.fetch(descriptor)
    }

    func insert(_ tab: GardenTab) throws {
        modelContext.insert(tab)
        try modelContext.save()
    }

    func delete(_ tab: GardenTab) throws {
        modelContext.delete(tab)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }
}
