import Foundation
import os
import SwiftData
import Observation

/// M09. Degrades rather than disappears without a conversational model: PlantNet's disease
/// API works on any device, so a check without AI still shows the disease codes with
/// templated recommendations instead of a narrated diagnosis.
@MainActor
@Observable
final class HealthViewModel {
    private let plantNetService: any PlantNetServiceProtocol
    private let modelContext: ModelContext
    private let aiRouter: AIRouter

    private(set) var recentChecks: [HealthCheck] = []
    private(set) var isDiagnosing = false
    private(set) var lastError: (any Error)?

    init(plantNetService: any PlantNetServiceProtocol, modelContext: ModelContext, aiRouter: AIRouter) {
        self.plantNetService = plantNetService
        self.modelContext = modelContext
        self.aiRouter = aiRouter
    }

    func load() {
        var descriptor = FetchDescriptor<HealthCheck>(sortBy: [SortDescriptor(\.checkedAt, order: .reverse)])
        descriptor.fetchLimit = 10
        recentChecks = (try? modelContext.fetch(descriptor)) ?? []
    }

    func diagnose(plant: Plant, photo: Data) async {
        isDiagnosing = true
        defer { isDiagnosing = false }

        do {
            let diseaseResponse = try await plantNetService.identifyDiseases(images: [photo])
            let codes = diseaseResponse.results.prefix(3).map { $0.name }

            var diagnosis = codes.isEmpty
                ? String(localized: "health.noIssuesFound", defaultValue: "No se detectaron señales claras de enfermedad.")
                : "PlantNet detectó posibles señales de: \(codes.joined(separator: ", "))."
            var recommendations = templatedRecommendations(for: codes)

            // Try each candidate in turn — same fix as chat and the watering correction: an
            // engine reporting "available" doesn't mean generation will actually succeed, so
            // one failure should try the next candidate rather than fall straight to the
            // templated diagnosis while a working engine (e.g. the user's own key) sits unused.
            for (engine, kind) in await aiRouter.conversationalEngineCandidates() {
                if let narrative = try? await engine.narrateHealthCheck(diseaseCodes: codes, context: "", photo: photo) {
                    diagnosis = narrative.diagnosis
                    recommendations = narrative.recommendations
                    modelContext.insert(AIAuditEntry(task: .healthDiagnosis, engine: kind, plant: plant))
                    // Additive, never a silent override: only fills a phase the user hasn't
                    // already set by hand in `PlantEditView`. Same "reglas siempre, IA
                    // aditiva" shape as the watering correction — a suggestion, not authority.
                    if let suggested = narrative.suggestedGrowthPhase, plant.growthPhase == nil {
                        plant.growthPhase = suggested
                        AppLog.checkpoint.notice("Health: suggested growth phase \(suggested.rawValue, privacy: .public) for plant \(plant.id, privacy: .public)")
                    }
                    break
                }
            }

            let check = HealthCheck(
                diagnosis: diagnosis,
                plantNetDiseaseCodesJSON: try? String(data: JSONEncoder().encode(codes), encoding: .utf8),
                photoData: photo,
                plant: plant
            )
            check.recommendations = recommendations
            modelContext.insert(check)
            modelContext.insert(AIAuditEntry(task: .healthDiagnosis, engine: .plantNet, plant: plant))
            try modelContext.save()
            load()
        } catch {
            lastError = error
            AppLog.plantData.error("Health diagnosis failed: \(error, privacy: .public)")
        }
    }

    private func templatedRecommendations(for codes: [String]) -> [String] {
        guard !codes.isEmpty else {
            return [String(localized: "health.templatedRec.keepMonitoring", defaultValue: "Sigue observando la planta en los próximos días.")]
        }
        return [
            String(localized: "health.templatedRec.isolate", defaultValue: "Aísla la planta de otras si puedes."),
            String(localized: "health.templatedRec.reduceWater", defaultValue: "Reduce el riego hasta ver mejoría."),
            String(localized: "health.templatedRec.retryPhoto", defaultValue: "Vuelve a fotografiar en unos días para comparar."),
        ]
    }
}
