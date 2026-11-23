import Foundation

/// Decides WHICH engine answers a given task, per the task-based routing agreed in the
/// design (docs/HANDOFF.md 3.1): the daily watering adjustment prefers on-device (highest
/// volume, doesn't need a bigger model); chat and diagnosis prefer PCC when available
/// (currently always unavailable — see PrivateCloudComputeEngine.swift), falling back to
/// on-device, falling back to the user's own key.
///
/// This is distinct from the OLD `AIServiceFactory`, which gave the user's own key absolute
/// priority for everything, including background work that didn't need it.
@MainActor
final class AIRouter {
    private let keychain: any KeychainServiceProtocol
    private var userKeyEngine: UserProvidedKeyEngine?

    init(keychain: any KeychainServiceProtocol) {
        self.keychain = keychain
        refreshUserKey()
    }

    func refreshUserKey() {
        if let key = try? keychain.read(key: KeychainKey.optionalLLMAPIKey), !key.isEmpty {
            userKeyEngine = UserProvidedKeyEngine(apiKey: key)
        } else {
            userKeyEngine = nil
        }
    }

    /// For the watering adjustment: on-device preferred, user key as a last resort. Never
    /// blocks the rule-engine baseline from applying — this is only for the bounded
    /// correction on top of it.
    ///
    /// Returns candidates in priority order rather than committing to one: `isAvailable` is
    /// only a shallow "is the model reported as ready" check, not "will generation actually
    /// work." Found live — `SystemLanguageModel.availability` said `.available` on a Mac whose
    /// model assets weren't actually downloaded, so the on-device engine passed the check and
    /// then threw the moment it was asked to generate, and the caller had already discarded
    /// every other option by then. The caller must try each candidate and fall through on
    /// failure instead of trusting the first one that merely LOOKS ready.
    func wateringEngineCandidates() async -> [(any AIEngine, AIEngineKind)] {
        var candidates: [(any AIEngine, AIEngineKind)] = []
        let onDevice = FoundationModelsEngine()
        if await onDevice.isAvailable { candidates.append((onDevice, .onDeviceFoundationModels)) }
        if let userKeyEngine { candidates.append((userKeyEngine, .userProvidedKey)) }
        return candidates
    }

    /// For chat and diagnosis: PCC preferred when eligible, on-device next, user key last.
    /// Same reasoning as `wateringEngineCandidates` — see its doc comment.
    func conversationalEngineCandidates() async -> [(any AIEngine, AIEngineKind)] {
        var candidates: [(any AIEngine, AIEngineKind)] = []
        let pcc = PrivateCloudComputeEngine()
        if await pcc.isAvailable { candidates.append((pcc, .privateCloudCompute)) }
        let onDevice = FoundationModelsEngine()
        if await onDevice.isAvailable { candidates.append((onDevice, .onDeviceFoundationModels)) }
        if let userKeyEngine { candidates.append((userKeyEngine, .userProvidedKey)) }
        return candidates
    }

    var hasUserProvidedKey: Bool { userKeyEngine != nil }
}
