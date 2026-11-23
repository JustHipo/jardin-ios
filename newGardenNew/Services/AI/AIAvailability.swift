import Foundation
import FoundationModels

/// The three distinct cases `SystemLanguageModel.availability` can report, each needing a
/// different message. Conflating them produces the worst possible message: telling someone
/// with an iPhone 11 to go activate a setting their hardware cannot have. Flagged as the
/// easy-to-miss detail in docs/ANALISIS_IMPLEMENTACION.md section 3.
enum AIAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case disabledBySystem
    case downloading

    static var current: AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .disabledBySystem
        case .unavailable(.modelNotReady):
            return .downloading
        @unknown default:
            return .deviceNotEligible
        }
    }

    var settingsMessage: String {
        switch self {
        case .available:
            ""
        case .deviceNotEligible:
            String(localized: "ai.availability.notEligible", defaultValue: "Tu iPhone no puede ejecutar la IA de Apple. Puedes usar tu propia clave en su lugar.")
        case .disabledBySystem:
            String(localized: "ai.availability.disabled", defaultValue: "Activa Apple Intelligence en Ajustes del sistema para usarla aquí.")
        case .downloading:
            String(localized: "ai.availability.downloading", defaultValue: "El modelo se está descargando. Vuelve a intentarlo en un momento.")
        }
    }
}
