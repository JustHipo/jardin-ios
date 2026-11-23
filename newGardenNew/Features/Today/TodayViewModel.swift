import Foundation
import os
import SwiftData
import Observation
import WidgetKit

/// P2/P3: the entry screen answers "what do I need to do", not "list my plants
/// alphabetically". Watering is one tap with a 5 second undo instead of a confirmation —
/// the confirmation protects against the same mistake the undo protects against, but adds
/// friction to the most frequent action in the product (H3 in the old audit).
@MainActor
@Observable
final class TodayViewModel {
    private let plantRepository: any PlantRepositoryProtocol
    private let wateringRepository: any WateringEventRepositoryProtocol
    private let settings: AppSettings

    private(set) var overdue: [Plant] = []
    private(set) var soon: [Plant] = []
    private(set) var fine: [Plant] = []
    private(set) var lastError: (any Error)?

    /// Plants watered in this session, pending the undo window. Kept separate from the model
    /// so undo can cleanly reverse the SwiftData write.
    private var pendingUndo: [UUID: WateringEvent] = [:]
    var undoVisibleFor: Plant?

    init(plantRepository: any PlantRepositoryProtocol, wateringRepository: any WateringEventRepositoryProtocol, settings: AppSettings) {
        self.plantRepository = plantRepository
        self.wateringRepository = wateringRepository
        self.settings = settings
    }

    func load() {
        do {
            let plants = try plantRepository.fetchAll()
            overdue = plants.filter { $0.wateringStatus == .overdue }
            soon = plants.filter { $0.wateringStatus == .soon }
            fine = plants.filter { $0.wateringStatus == .ok || $0.wateringStatus == .neverWatered }
            lastError = nil
            NotificationScheduler.updateBadge(overdueCount: overdue.count)
            AppLog.checkpoint.notice("Today: load() — \(plants.count, privacy: .public) total, \(self.overdue.count, privacy: .public) overdue, \(self.soon.count, privacy: .public) soon, \(self.fine.count, privacy: .public) fine")
        } catch {
            lastError = error
            AppLog.watering.error("Failed to load plants for Today: \(error, privacy: .public)")
            AppLog.checkpoint.notice("Today: load() FAILED — \(error, privacy: .public)")
        }
    }

    /// One tap, immediate visual feedback, 5 second undo window (P3).
    func water(_ plant: Plant) {
        let event = WateringEvent(source: "app", plant: plant)
        do {
            try wateringRepository.insert(event)
            pendingUndo[plant.id] = event
            undoVisibleFor = plant
            AppLog.checkpoint.notice("Today: watered plant \(plant.id, privacy: .public), undo window open")
            load()
            WidgetCenter.shared.reloadTimelines(ofKind: GardenWidgetKind.identifier)
        } catch {
            lastError = error
            AppLog.watering.error("Failed to record watering: \(error, privacy: .public)")
            AppLog.checkpoint.notice("Today: water() FAILED — \(error, privacy: .public)")
        }
    }

    func undo(_ plant: Plant) {
        guard let event = pendingUndo[plant.id] else {
            AppLog.checkpoint.notice("Today: undo() called but no pending watering for \(plant.id, privacy: .public)")
            return
        }
        do {
            try wateringRepository.delete(event)
            pendingUndo[plant.id] = nil
            undoVisibleFor = nil
            AppLog.checkpoint.notice("Today: undid watering for \(plant.id, privacy: .public)")
            load()
            WidgetCenter.shared.reloadTimelines(ofKind: GardenWidgetKind.identifier)
        } catch {
            lastError = error
            AppLog.checkpoint.notice("Today: undo() FAILED — \(error, privacy: .public)")
        }
    }

    func dismissUndo() {
        undoVisibleFor = nil
        pendingUndo.removeAll()
    }
}
