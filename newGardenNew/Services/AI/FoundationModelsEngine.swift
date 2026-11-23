import Foundation
import os
import FoundationModels

/// The on-device Foundation Models engine.
///
/// IMPORTANT — toolchain constraint, not a design choice: the installed Xcode (26.3) ships
/// only the iOS 26.2 SDK. The `LanguageModel` protocol and `PrivateCloudComputeLanguageModel`
/// confirmed against Apple's WWDC26 sessions (docs/ANALISIS_IMPLEMENTACION.md section 2) are
/// iOS 27 SDK additions that do not exist in this SDK's `FoundationModels.swiftinterface` —
/// verified directly, not assumed. This file can therefore only build against
/// `SystemLanguageModel`. See `PrivateCloudComputeEngine.swift` for the PCC side and exactly
/// what to change once Xcode updates.
final class FoundationModelsEngine: AIEngine {
    private let model: SystemLanguageModel

    init(model: SystemLanguageModel = .default) {
        self.model = model
    }

    var isAvailable: Bool {
        get async {
            model.availability == .available
        }
    }

    func proposeWateringCorrection(
        plant: Plant,
        ruleBaselineDays: Int,
        context: String,
        recentPhotos: [Data]
    ) async throws -> WateringCorrection {
        let session = LanguageModelSession(
            model: model,
            instructions: Prompts.wateringAnalysisSystem(city: nil, context: nil)
        )

        do {
            let response = try await session.respond(
                to: "Datos de la planta y el clima:\n\(context)",
                generating: WateringCorrectionResponse.self
            )
            let r = response.content
            let clamped = max(-2, min(2, r.adjustDaysCorrection))
            return WateringCorrection(
                days: clamped,
                confidence: r.confidence,
                reasoning: r.reasoning,
                wateringTip: r.wateringTip,
                plantProfile: r.plantProfile,
                environmentalFactors: r.environmentalFactors,
                riskAssessment: r.riskAssessment
            )
        } catch {
            AppLog.ai.error("Foundation Models watering correction failed: \(error, privacy: .public)")
            throw AIEngineError.underlying(String(describing: error))
        }
    }

    func reply(
        toUserMessage message: String,
        conversation: [ChatMessage],
        groundingContext: String
    ) async throws -> ChatReply {
        let instructions = """
            Respondes preguntas sobre UNA planta concreta, usando solo el contexto que se te da.
            Si algo no está en el contexto, dilo en vez de inventarlo. Cita de qué fuente sale
            cada afirmación cuando puedas (PlantNet, Trefle, WeatherKit, el historial de riego,
            las fotos, o lo que escribió el usuario).

            Contexto de esta planta:
            \(groundingContext)
            """
        AppLog.checkpoint.notice("""
            Foundation Models request:
            --- instructions ---
            \(instructions, privacy: .public)
            --- message ---
            \(message, privacy: .public)
            """)
        let session = LanguageModelSession(model: model, instructions: instructions)

        do {
            let response = try await session.respond(to: message)
            AppLog.checkpoint.notice("Foundation Models: reply \(response.content.count, privacy: .public) chars")
            return ChatReply(text: response.content, citations: [])
        } catch {
            AppLog.ai.error("Foundation Models chat reply failed: \(error, privacy: .public)")
            AppLog.checkpoint.notice("Foundation Models: reply FAILED — \(error, privacy: .public)")
            throw AIEngineError.underlying(String(describing: error))
        }
    }

    func narrateHealthCheck(diseaseCodes: [String], context: String, photo: Data?) async throws -> HealthNarrative {
        let session = LanguageModelSession(model: model, instructions: Prompts.healthAnalysisSystem())
        let prompt = "Códigos de enfermedad detectados por PlantNet: \(diseaseCodes.joined(separator: ", ")).\nContexto:\n\(context)"

        do {
            let response = try await session.respond(to: prompt, generating: HealthNarrativeResponse.self)
            return HealthNarrative(
                diagnosis: response.content.diagnosis,
                recommendations: response.content.recommendations,
                suggestedGrowthPhase: response.content.growthPhase.flatMap(GrowthPhase.init(rawValue:))
            )
        } catch {
            AppLog.ai.error("Foundation Models health narrative failed: \(error, privacy: .public)")
            throw AIEngineError.underlying(String(describing: error))
        }
    }
}

// MARK: - Generable response shapes

@Generable
struct WateringCorrectionResponse {
    @Guide(description: "Bounded correction to the rule engine's baseline, -2 to 2 days. 0 if no visual reason.")
    var adjustDaysCorrection: Int
    @Guide(description: "low, medium, or high")
    var confidence: String
    var reasoning: String
    var wateringTip: String
    var plantProfile: String
    var environmentalFactors: String
    var riskAssessment: String
}

@Generable
struct HealthNarrativeResponse {
    var diagnosis: String
    @Guide(description: "Up to 3 concrete, actionable recommendations")
    var recommendations: [String]
    @Guide(description: "vegetative, flowering, fruiting, or dormant — your best visual guess, or nil if the photo doesn't make it clear")
    var growthPhase: String?
}
