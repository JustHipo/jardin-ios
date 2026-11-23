import Foundation
import SwiftData

@Model
final class CareStep {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var dueDate: Date?
    var soonDays: Int = 3

    var plant: Plant?
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        soonDays: Int = 3,
        plant: Plant? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.soonDays = soonDays
        self.plant = plant
        self.createdAt = createdAt
    }
}
