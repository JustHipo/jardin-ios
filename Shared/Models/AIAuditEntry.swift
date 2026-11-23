import Foundation
import SwiftData

/// Which engine actually answered. Recorded on every AI-adjacent operation so the app can
/// say, in the user's language, whether their data left the device — and so we can tell,
/// months later, that a given day's adjustment came from the rule engine alone because the
/// PCC quota was exhausted. See docs/ANALISIS_IMPLEMENTACION.md section 3.
enum AIEngineKind: String, Sendable, CaseIterable, Codable {
    /// The deterministic water balance engine. Runs on every device, always.
    case ruleEngine
    /// Apple's on-device Foundation Models.
    case onDeviceFoundationModels
    /// Apple's Private Cloud Compute.
    case privateCloudCompute
    /// The user's own OpenAI/Anthropic key.
    case userProvidedKey
    /// PlantNet's classifier (species or disease identification, not a language model).
    case plantNet
}

/// What task the entry is about.
enum AITaskKind: String, Sendable, CaseIterable, Codable {
    case wateringAdjustment
    case speciesIdentification
    case healthDiagnosis
    case chat
}

/// An auditable record of one AI-adjacent operation: which engine answered, what it was
/// asked, roughly how long it took, and whether it succeeded. This is what makes the AI
/// auditable per P4 — it is what the source chips in M03/M04/M09 are ultimately reading.
@Model
final class AIAuditEntry {
    var id: UUID = UUID()
    var occurredAt: Date = Date.now
    var taskRaw: String = AITaskKind.wateringAdjustment.rawValue
    var engineRaw: String = AIEngineKind.ruleEngine.rawValue
    var durationMs: Int?
    var succeeded: Bool = true
    /// Human-readable reason the engine fell back (quota exhausted, offline, not eligible).
    var fallbackReason: String?
    /// JSON-encoded [String] naming the data sources actually consulted (PlantNet, Trefle,
    /// WeatherKit, "Tu historial", "Tus fotos", "Lo que escribiste).
    var sourcesUsedJSON: String?

    var plant: Plant?

    init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        task: AITaskKind,
        engine: AIEngineKind,
        durationMs: Int? = nil,
        succeeded: Bool = true,
        fallbackReason: String? = nil,
        sourcesUsed: [String] = [],
        plant: Plant? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.taskRaw = task.rawValue
        self.engineRaw = engine.rawValue
        self.durationMs = durationMs
        self.succeeded = succeeded
        self.fallbackReason = fallbackReason
        self.sourcesUsedJSON = Self.encode(sourcesUsed)
        self.plant = plant
    }

    var task: AITaskKind { AITaskKind(rawValue: taskRaw) ?? .wateringAdjustment }
    var engine: AIEngineKind { AIEngineKind(rawValue: engineRaw) ?? .ruleEngine }

    var sourcesUsed: [String] {
        get {
            guard let json = sourcesUsedJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set { sourcesUsedJSON = Self.encode(newValue) }
    }

    private static func encode(_ values: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(values) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
