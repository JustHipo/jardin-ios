import Foundation
import os
import Observation

/// M02: the full library, one level deeper than the entry screen (P2). The photo is the
/// emotional content of this app and gets the grid's full width, not a 60pt thumbnail
/// (finding 8.9 of the redesign report).
@MainActor
@Observable
final class LibraryViewModel {
    private let plantRepository: any PlantRepositoryProtocol
    private(set) var plants: [Plant] = []
    private(set) var lastError: (any Error)?
    var filter: DSWateringState?
    var searchText: String = ""

    init(plantRepository: any PlantRepositoryProtocol) {
        self.plantRepository = plantRepository
    }

    func load() {
        do {
            plants = try plantRepository.fetchAll()
            lastError = nil
        } catch {
            lastError = error
            AppLog.app.error("Failed to load plants for Library: \(error, privacy: .public)")
        }
    }

    var filtered: [Plant] {
        var result = plants
        if let filter { result = result.filter { $0.dsWateringState == filter } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.species ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    func count(for state: DSWateringState?) -> Int {
        guard let state else { return plants.count }
        return plants.filter { $0.dsWateringState == state }.count
    }
}
