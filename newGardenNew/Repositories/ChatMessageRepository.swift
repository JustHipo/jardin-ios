import Foundation
import SwiftData

protocol ChatMessageRepositoryProtocol {
    func fetchForPlant(_ plant: Plant) throws -> [ChatMessage]
    func insert(_ message: ChatMessage) throws
    func save() throws
}

struct ChatMessageRepository: ChatMessageRepositoryProtocol {
    let modelContext: ModelContext

    func fetchForPlant(_ plant: Plant) throws -> [ChatMessage] {
        let plantId = plant.id
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.plant?.id == plantId },
            sortBy: [SortDescriptor(\.sentAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    func insert(_ message: ChatMessage) throws {
        modelContext.insert(message)
        try modelContext.save()
    }

    func save() throws {
        try modelContext.save()
    }
}
