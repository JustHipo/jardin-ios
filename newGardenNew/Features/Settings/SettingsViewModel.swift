import Foundation
import Observation

/// M10: from 10 sections to 4, because API keys stop being mandatory. The "IA en tu
/// iPhone" row needs the three distinct messages agreed with the design session — telling
/// someone with an ineligible device to "activate" a setting their hardware cannot have is
/// the worst possible message (docs/ANALISIS_IMPLEMENTACION.md section 3).
@MainActor
@Observable
final class SettingsViewModel {
    private let keychain: any KeychainServiceProtocol
    private let aiRouter: AIRouter
    /// Lets Trefle's service be rebuilt in `AppDependencies` right after the token changes,
    /// without coupling this ViewModel to that concrete type.
    private let onTrefleTokenChanged: () -> Void

    var userAPIKeyDraft: String = ""
    private(set) var hasUserKey: Bool = false

    var trefleTokenDraft: String = ""
    private(set) var hasTrefleToken: Bool = false

    init(keychain: any KeychainServiceProtocol, aiRouter: AIRouter, onTrefleTokenChanged: @escaping () -> Void = {}) {
        self.keychain = keychain
        self.aiRouter = aiRouter
        self.onTrefleTokenChanged = onTrefleTokenChanged
        self.hasUserKey = aiRouter.hasUserProvidedKey
        self.hasTrefleToken = (try? keychain.read(key: KeychainKey.trefleAPIToken))?.isEmpty == false
    }

    var aiAvailability: AIAvailability { AIAvailability.current }

    func saveUserKey() {
        // Trimmed: a paste from Notes/chat often carries an invisible trailing newline or
        // space, which silently turns a valid key into one that always 401s. Found live with
        // the Trefle token below — same risk applies here.
        let trimmed = userAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? keychain.save(key: KeychainKey.optionalLLMAPIKey, value: trimmed)
        aiRouter.refreshUserKey()
        hasUserKey = true
        userAPIKeyDraft = ""
    }

    func removeUserKey() {
        try? keychain.delete(key: KeychainKey.optionalLLMAPIKey)
        aiRouter.refreshUserKey()
        hasUserKey = false
    }

    /// Trefle is optional and degrades gracefully without it (docs/HANDOFF.md 3.5) — this is
    /// just the missing Settings field for a token the service already knew how to read.
    func saveTrefleToken() {
        // Found live: a stored token one character longer than the real one (a trailing
        // space from pasting) made every Trefle request 401 silently — trimming here is
        // what actually fixes it, not just a defensive nicety.
        let trimmed = trefleTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? keychain.save(key: KeychainKey.trefleAPIToken, value: trimmed)
        onTrefleTokenChanged()
        hasTrefleToken = true
        trefleTokenDraft = ""
    }

    func removeTrefleToken() {
        try? keychain.delete(key: KeychainKey.trefleAPIToken)
        onTrefleTokenChanged()
        hasTrefleToken = false
    }
}
