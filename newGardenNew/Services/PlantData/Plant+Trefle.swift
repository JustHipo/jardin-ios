import Foundation

/// `Plant.trefleDetailJSON` is a plain opaque string in the shared model (so the widget
/// target, which has no reason to know about Trefle's response shape, doesn't need to
/// compile `TrefleModels.swift`) — this is where the app decodes/encodes it into the real
/// type. See `AddPlantViewModel` (where this gets populated right after identification) and
/// `WateringOrchestrator.resolveTrefle` (which reads this cache before ever hitting the
/// network).
extension Plant {
    var cachedTrefleData: TrefleSpeciesFullData? {
        guard let json = trefleDetailJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TrefleSpeciesFullData.self, from: data)
    }

    func cacheTrefleData(id: Int, data: TrefleSpeciesFullData) {
        guard let encoded = try? JSONEncoder().encode(data), let jsonString = String(data: encoded, encoding: .utf8) else { return }
        trefleId = id
        trefleDetailJSON = jsonString
    }
}
