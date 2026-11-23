import Foundation
import os

/// Bring-your-own-key engine: OpenAI or Anthropic, entered voluntarily in Ajustes under
/// "IA avanzada (opcional)". Never governs background work — see
/// docs/REPORTE_ESTADO_Y_REDISENO.md 3.1, this is the degraded-not-eliminated fate of the
/// old default engines. Minimal Chat Completions-shaped client; expand per-provider once a
/// key is actually supplied and tested.
final class UserProvidedKeyEngine: AIEngine {
    private let apiKey: String
    private let baseURL: URL
    private let model: String

    init(apiKey: String, baseURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }

    var isAvailable: Bool { get async { !apiKey.isEmpty } }

    func proposeWateringCorrection(plant: Plant, ruleBaselineDays: Int, context: String, recentPhotos: [Data]) async throws -> WateringCorrection {
        let text = try await complete(
            system: Prompts.wateringAnalysisSystem(city: nil, context: nil),
            user: context
        )
        guard let data = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(WateringCorrectionJSON.self, from: data) else {
            throw AIEngineError.decodingFailed
        }
        let clamped = max(-2, min(2, parsed.recommendation.adjust_days_correction))
        return WateringCorrection(
            days: clamped,
            confidence: parsed.recommendation.confidence,
            reasoning: parsed.recommendation.reasoning,
            wateringTip: parsed.recommendation.watering_tip,
            plantProfile: parsed.analysis.plant_profile,
            environmentalFactors: parsed.analysis.environmental_factors,
            riskAssessment: parsed.analysis.risk_assessment
        )
    }

    func reply(toUserMessage message: String, conversation: [ChatMessage], groundingContext: String) async throws -> ChatReply {
        let text = try await complete(
            system: "Respondes preguntas sobre esta planta usando solo el contexto dado:\n\(groundingContext)",
            user: message
        )
        return ChatReply(text: text, citations: [])
    }

    func narrateHealthCheck(diseaseCodes: [String], context: String, photo: Data?) async throws -> HealthNarrative {
        let text = try await complete(system: Prompts.healthAnalysisSystem(), user: context)
        guard let data = text.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(HealthCheckJSON.self, from: data) else {
            throw AIEngineError.decodingFailed
        }
        return HealthNarrative(
            diagnosis: parsed.diagnosis,
            recommendations: parsed.recommendations,
            suggestedGrowthPhase: parsed.growth_phase.flatMap(GrowthPhase.init(rawValue:))
        )
    }

    private func complete(system: String, user: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // The exact prompt sent, in full — this IS "el prompt que le enviamos" the owner asked to
        // see. Never at .error/.default so it never gets sent up as a crash-adjacent log,
        // but always visible with `log show` since checkpoint sits at .notice.
        AppLog.checkpoint.notice("""
            OpenAI request to \(self.model, privacy: .public):
            --- system ---
            \(system, privacy: .public)
            --- user ---
            \(user, privacy: .public)
            """)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            AppLog.checkpoint.notice("OpenAI: HTTP \(status, privacy: .public) — \(body.prefix(500), privacy: .public)")
            throw AIEngineError.underlying("HTTP \(status) from user-provided key endpoint")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            AppLog.checkpoint.notice("OpenAI: HTTP \(status, privacy: .public), response shape unexpected")
            throw AIEngineError.decodingFailed
        }
        AppLog.checkpoint.notice("OpenAI: HTTP \(status, privacy: .public), reply \(content.count, privacy: .public) chars")
        return content
    }
}

private struct WateringCorrectionJSON: Codable {
    struct Analysis: Codable {
        let plant_profile: String
        let environmental_factors: String
        let risk_assessment: String
    }
    struct Recommendation: Codable {
        let adjust_days_correction: Int
        let confidence: String
        let reasoning: String
        let watering_tip: String
    }
    let analysis: Analysis
    let recommendation: Recommendation
}

private struct HealthCheckJSON: Codable {
    let health_score: Int
    let health_status: String
    let issues: [String]
    let diagnosis: String
    let recommendations: [String]
    let watering_note: String?
    let growth_phase: String?
}
