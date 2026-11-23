import Foundation

/// Placeholder for Private Cloud Compute, confirmed to exist in iOS 27 (WWDC26 session 319,
/// docs/ANALISIS_IMPLEMENTACION.md section 2) but NOT present in the iOS 26.2 SDK this
/// project currently builds against — verified against the installed
/// `FoundationModels.swiftinterface`, which has no `PrivateCloudComputeLanguageModel` or
/// `LanguageModel` protocol yet.
///
/// This always reports unavailable rather than failing to compile. To activate PCC once
/// Xcode ships the iOS 27 SDK:
///
/// 1. Replace this file's body with a real `PrivateCloudComputeLanguageModel()`-backed
///    engine, mirroring `FoundationModelsEngine` but constructing that model instead of
///    `SystemLanguageModel.default`.
/// 2. In `AIRouter.conversationalEngine()`, swap this placeholder for the real one behind
///    the existing `#available(iOS 27.0, *)` check — the call site is already written for
///    this and does not need to change.
/// 3. Also confirm the owner submitted the PCC request Apple requires (pending item, see
///    docs/ANALISIS_IMPLEMENTACION.md section 7) — the API existing is necessary but not
///    sufficient; the app's account needs to be enrolled.
final class PrivateCloudComputeEngine: AIEngine {
    var isAvailable: Bool { get async { false } }

    func proposeWateringCorrection(plant: Plant, ruleBaselineDays: Int, context: String, recentPhotos: [Data]) async throws -> WateringCorrection {
        throw AIEngineError.notAvailable
    }

    func reply(toUserMessage message: String, conversation: [ChatMessage], groundingContext: String) async throws -> ChatReply {
        throw AIEngineError.notAvailable
    }

    func narrateHealthCheck(diseaseCodes: [String], context: String, photo: Data?) async throws -> HealthNarrative {
        throw AIEngineError.notAvailable
    }
}
