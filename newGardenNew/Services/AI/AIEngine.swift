import Foundation

/// A bounded, motivated correction to the rule engine's baseline. The AI is never allowed to
/// set the cycle outright — see docs/ANALISIS_IMPLEMENTACION.md section 3: if it could, the
/// same plant with the same weather would get a different calendar depending on the user's
/// hardware. `days` is clamped to -2...2 by the router regardless of what the model returns.
struct WateringCorrection: Sendable {
    let days: Int
    let confidence: String
    let reasoning: String
    let wateringTip: String
    let plantProfile: String
    let environmentalFactors: String
    let riskAssessment: String

    /// Only apply when the model is confident AND gave a concrete visual reason.
    var shouldApply: Bool { confidence == "high" && days != 0 }
}

struct ChatReply: Sendable {
    let text: String
    /// Sources actually consulted while answering, as a frozen snapshot.
    let citations: [ChatSourceCitation]
}

struct HealthNarrative: Sendable {
    let diagnosis: String
    let recommendations: [String]
    /// A guess at the plant's current growth phase from what the photo shows (budding,
    /// pods/fruit visible, dormant-looking...). Additive only — `HealthViewModel` applies it
    /// to the plant just like any other suggestion, never silently overriding a phase the
    /// user already set by hand in `PlantEditView`.
    let suggestedGrowthPhase: GrowthPhase?
}

/// What the app needs from a language model, kept deliberately narrow. Concrete
/// implementations: `FoundationModelsEngine` (on-device or PCC, selected by the caller) and
/// `UserProvidedKeyEngine` (OpenAI/Anthropic, optional, never governs background work — see
/// docs/REPORTE_ESTADO_Y_REDISENO.md 3.1).
protocol AIEngine: Sendable {
    var isAvailable: Bool { get async }

    func proposeWateringCorrection(
        plant: Plant,
        ruleBaselineDays: Int,
        context: String,
        recentPhotos: [Data]
    ) async throws -> WateringCorrection

    func reply(
        toUserMessage message: String,
        conversation: [ChatMessage],
        groundingContext: String
    ) async throws -> ChatReply

    func narrateHealthCheck(
        diseaseCodes: [String],
        context: String,
        photo: Data?
    ) async throws -> HealthNarrative
}

enum AIEngineError: Error, LocalizedError, Sendable {
    case notAvailable
    case quotaExhausted
    case decodingFailed
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            String(localized: "ai.error.notAvailable", defaultValue: "El modelo de IA no está disponible en este dispositivo.")
        case .quotaExhausted:
            String(localized: "ai.error.quotaExhausted", defaultValue: "Se agotó la cuota de este motor por hoy.")
        case .decodingFailed:
            String(localized: "ai.error.decoding", defaultValue: "La IA respondió en un formato inesperado.")
        case .underlying(let message):
            message
        }
    }
}
