import Foundation
import WidgetKit

/// A widget-sized view of one plant — just what the three faces (M11 mockup) actually show.
/// Built from `Plant` at snapshot time; never stores a live reference across a timeline.
struct WidgetPlantInfo: Identifiable {
    let id: UUID
    let name: String
    let photoData: Data?
    let subtitle: String
    let isOverdue: Bool

    init(_ plant: Plant) {
        id = plant.id
        name = plant.name
        photoData = plant.photoData
        isOverdue = plant.wateringStatus == .overdue

        if let days = plant.daysUntilDue {
            if days < 0 {
                let overdueBy = -days
                subtitle = overdueBy == 1 ? "Hace 1 día" : "Hace \(overdueBy) días"
            } else if days == 0 {
                subtitle = "Hoy"
            } else {
                subtitle = days == 1 ? "En 1 día" : "En \(days) días"
            }
        } else {
            subtitle = "Sin registro"
        }
    }
}

struct GardenWidgetEntry: TimelineEntry {
    let date: Date
    /// Up to 3, sorted most-overdue first. Empty means nothing needs water right now.
    let overduePlants: [WidgetPlantInfo]
    /// "Nunca queda vacío" (M11 mockup): when nothing is overdue, the next plant due and
    /// when — nil only when there isn't a single watered plant yet to predict from.
    let nextPlant: WidgetPlantInfo?
}
