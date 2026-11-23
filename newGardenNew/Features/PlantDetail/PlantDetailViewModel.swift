import Foundation
import os
import SwiftData
import Observation
import WidgetKit

/// M03. The AI card here is the concrete instance of the "reglas siempre, IA aditiva"
/// design (docs/ANALISIS_IMPLEMENTACION.md section 3): `runAnalysis` always produces a
/// result from `WateringOrchestrator`, which itself never lets the AI author the number
/// alone. `AIAnalysis.ruleBaselineDays`/`aiCorrectionDays` are kept separate so the UI can
/// say "reglas: cada 5 días, la IA lo bajó a 4" instead of presenting one opaque number.
@MainActor
@Observable
final class PlantDetailViewModel {
    private let plantId: UUID
    private let plantRepository: any PlantRepositoryProtocol
    private let wateringRepository: any WateringEventRepositoryProtocol
    private let orchestrator: WateringOrchestrator?

    private(set) var plant: Plant?
    private(set) var latestAnalysis: AIAnalysis?
    private(set) var recentEvents: [WateringEvent] = []
    private(set) var isAnalyzing = false
    private(set) var lastError: (any Error)?
    var adjustmentDecision: Bool?

    init(
        plantId: UUID,
        plantRepository: any PlantRepositoryProtocol,
        wateringRepository: any WateringEventRepositoryProtocol,
        orchestrator: WateringOrchestrator?
    ) {
        self.plantId = plantId
        self.plantRepository = plantRepository
        self.wateringRepository = wateringRepository
        self.orchestrator = orchestrator
    }

    func load() {
        do {
            plant = try plantRepository.fetchById(plantId)
            if let plant {
                recentEvents = try wateringRepository.fetchForPlant(plant)
                latestAnalysis = (plant.aiAnalyses ?? []).max(by: { $0.analyzedAt < $1.analyzedAt })
            }
        } catch {
            lastError = error
        }
    }

    /// `appliedMl` is optional on purpose: the one-tap "Regar" flow stays one tap for anyone
    /// who doesn't measure. See `WateringEvent.appliedMl`'s doc comment for what logging it
    /// actually buys — a real calibration signal instead of assuming every watering fills the
    /// pot to capacity.
    func water(appliedMl: Double? = nil) {
        guard let plant else { return }
        do {
            try wateringRepository.insert(WateringEvent(source: "app", appliedMl: appliedMl, plant: plant))
            load()
            WidgetCenter.shared.reloadTimelines(ofKind: GardenWidgetKind.identifier)
        } catch {
            lastError = error
        }
    }

    func runAnalysis() async {
        guard let plant, let orchestrator else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            latestAnalysis = try await orchestrator.analyzePlant(plant)
            load()
        } catch {
            lastError = error
            AppLog.watering.error("Manual analysis failed: \(error, privacy: .public)")
        }
    }

    /// P4: the accept/discard step that makes the AI's correction auditable and reversible,
    /// not a fact imposed on the user.
    func acceptAdjustment(_ accept: Bool) {
        guard let plant, let analysis = latestAnalysis else { return }
        adjustmentDecision = accept
        if !accept {
            plant.waterEveryDaysAdjusted = plant.waterEveryDays + (analysis.ruleBaselineDays.map { $0 - plant.waterEveryDays } ?? 0)
            try? plantRepository.save()
        }
    }

    var petSafetyVerdict: PetSafetyVerdict {
        guard let plant else { return .unknown }
        if plant.isToxicToDogs == true || plant.isToxicToCats == true {
            return .toxic(notes: plant.toxicityNotes)
        }
        if plant.isToxicToDogs == false && plant.isToxicToCats == false {
            return .safe
        }
        return .unknown
    }
}
