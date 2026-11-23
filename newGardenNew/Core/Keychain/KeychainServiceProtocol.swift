import Foundation

/// Keys stored in the Keychain.
///
/// The redesign removes API keys from the user's path: PlantNet ships embedded under its
/// non-profit plan, WeatherKit needs no key, and the AI runs on-device by default. What is
/// left here is strictly optional: a Trefle token for extra botanical precision, and a
/// bring-your-own key for users who prefer a third party model.
enum KeychainKey {
    /// Optional user supplied key for OpenAI or Anthropic. Never governs background work.
    static let optionalLLMAPIKey = "com.ipo.newGardenNew.llm-api-key"
    /// Optional Trefle token. Without it the app degrades gracefully.
    static let trefleAPIToken = "com.ipo.newGardenNew.trefle-api-token"
}

protocol KeychainServiceProtocol: Sendable {
    func save(key: String, value: String) throws
    func read(key: String) throws -> String?
    func delete(key: String) throws
}
