import Foundation
import SwiftData

/// A watering cycle adjustment. Split out from the old catch-all `AIAnalysis`, which reused
/// the same fields for identification, watering and health with different meanings depending
/// on `analysisType` — e.g. `plantProfile` held a health score in one case and a text profile
/// in another. See docs/ANALISIS_IMPLEMENTACION.md section 4.
///
/// `adjustDays` here is always the FINAL adjustment applied, after combining the rule engine
/// baseline with any AI correction. `ruleBaselineDays` and `aiCorrectionDays` keep the two
/// apart so the UI can show "reglas: cada 5 días, la IA lo bajó a 4" (see AIAuditEntry for the
/// engine that produced each part).
@Model
final class AIAnalysis {
    var id: UUID = UUID()
    var analyzedAt: Date = Date.now
    var durationMs: Int?

    /// The cycle length the deterministic water balance engine computed, before any AI
    /// correction. Always present — this engine runs on every device.
    var ruleBaselineDays: Int?
    /// The bounded correction (-2...+2) the AI proposed, if any and if it was applied.
    var aiCorrectionDays: Int?
    /// Final adjustment actually applied to `Plant.waterEveryDaysAdjusted`.
    var adjustDays: Int = 0

    var confidence: String?
    var reasoning: String?
    var plantProfile: String?
    var environmentalFactors: String?
    var riskAssessment: String?
    var wateringTip: String?

    var plant: Plant?

    init(
        id: UUID = UUID(),
        analyzedAt: Date = .now,
        durationMs: Int? = nil,
        ruleBaselineDays: Int? = nil,
        aiCorrectionDays: Int? = nil,
        adjustDays: Int = 0,
        confidence: String? = nil,
        reasoning: String? = nil,
        plantProfile: String? = nil,
        environmentalFactors: String? = nil,
        riskAssessment: String? = nil,
        wateringTip: String? = nil,
        plant: Plant? = nil
    ) {
        self.id = id
        self.analyzedAt = analyzedAt
        self.durationMs = durationMs
        self.ruleBaselineDays = ruleBaselineDays
        self.aiCorrectionDays = aiCorrectionDays
        self.adjustDays = adjustDays
        self.confidence = confidence
        self.reasoning = reasoning
        self.plantProfile = plantProfile
        self.environmentalFactors = environmentalFactors
        self.riskAssessment = riskAssessment
        self.wateringTip = wateringTip
        self.plant = plant
    }
}
