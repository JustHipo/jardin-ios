import Foundation
import os

/// Ported from the old codebase, functionally unchanged: Trefle stays optional, and the app
/// degrades gracefully without a token (P1, decision agreed with the design session). Only
/// the 15 `print()` calls become `os.Logger`.
protocol TrefleServiceProtocol: Sendable {
    func searchSpecies(query: String) async throws -> [TrefleSpecies]
    func getSpeciesDetail(id: Int) async throws -> TrefleSpeciesDetailResult
}

nonisolated final class TrefleService: TrefleServiceProtocol, Sendable {
    private let token: String
    private let baseURL = "https://trefle.io/api/v1"

    init(token: String) {
        self.token = token
        // Length-only, never the token itself — but enough to catch a corrupted paste
        // (found live: the on-screen keyboard's "type" simulation silently swapped a
        // hyphen for an apostrophe, which no amount of trimming would have caught).
        let masked = token.count > 8 ? "\(token.prefix(6))…\(token.suffix(4)) (\(token.count) chars)" : "\(token.count) chars"
        AppLog.checkpoint.notice("Trefle: token configured, \(masked, privacy: .public)")
    }

    func searchSpecies(query: String) async throws -> [TrefleSpecies] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        let url = URL(string: "\(baseURL)/species/search?q=\(encoded)&token=\(token)")!
        AppLog.checkpoint.notice("Trefle: GET species/search q=\(query, privacy: .public)")
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.plantData.debug("Trefle species search status: \(status)")
        do {
            let results = try JSONDecoder().decode(TrefleSpeciesSearchResult.self, from: data).data
            AppLog.checkpoint.notice("Trefle: species/search -> HTTP \(status, privacy: .public), \(results.count, privacy: .public) results")
            return results
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8, \(data.count) bytes>"
            AppLog.checkpoint.notice("Trefle: species/search -> HTTP \(status, privacy: .public), decode failed: \(error, privacy: .public), body: \(body.prefix(500), privacy: .public)")
            throw error
        }
    }

    func getSpeciesDetail(id: Int) async throws -> TrefleSpeciesDetailResult {
        let url = URL(string: "\(baseURL)/species/\(id)?token=\(token)")!
        AppLog.checkpoint.notice("Trefle: GET species/\(id, privacy: .public)")
        let (data, response) = try await URLSession.shared.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        AppLog.plantData.debug("Trefle species detail status: \(status)")
        do {
            let result = try JSONDecoder().decode(TrefleSpeciesDetailResult.self, from: data)
            AppLog.checkpoint.notice("Trefle: species/\(id, privacy: .public) -> HTTP \(status, privacy: .public), decoded OK")
            return result
        } catch {
            AppLog.checkpoint.notice("Trefle: species/\(id, privacy: .public) -> HTTP \(status, privacy: .public), decode failed: \(error, privacy: .public)")
            throw error
        }
    }
}
