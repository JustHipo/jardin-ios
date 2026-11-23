import Foundation
import SwiftData

/// A health/disease check (M09). Split out from the old `AIAnalysis` so `healthScore` is a
/// typed field instead of a number smuggled through `plantProfile`.
@Model
final class HealthCheck {
    var id: UUID = UUID()
    var checkedAt: Date = Date.now

    var healthScore: Int?
    /// "excellent", "good", "fair", "poor", "critical"
    var statusRaw: String?
    var diagnosis: String?
    /// JSON-encoded [String]
    var issuesJSON: String?
    /// JSON-encoded [String]
    var recommendationsJSON: String?
    var wateringNote: String?

    /// EPPO disease codes PlantNet returned, JSON-encoded [String]. Present even without AI,
    /// since PlantNet's disease API works on any device.
    var plantNetDiseaseCodesJSON: String?

    @Attribute(.externalStorage) var photoData: Data?

    var plant: Plant?

    init(
        id: UUID = UUID(),
        checkedAt: Date = .now,
        healthScore: Int? = nil,
        statusRaw: String? = nil,
        diagnosis: String? = nil,
        issuesJSON: String? = nil,
        recommendationsJSON: String? = nil,
        wateringNote: String? = nil,
        plantNetDiseaseCodesJSON: String? = nil,
        photoData: Data? = nil,
        plant: Plant? = nil
    ) {
        self.id = id
        self.checkedAt = checkedAt
        self.healthScore = healthScore
        self.statusRaw = statusRaw
        self.diagnosis = diagnosis
        self.issuesJSON = issuesJSON
        self.recommendationsJSON = recommendationsJSON
        self.wateringNote = wateringNote
        self.plantNetDiseaseCodesJSON = plantNetDiseaseCodesJSON
        self.photoData = photoData
        self.plant = plant
    }

    var issues: [String] {
        get { Self.decode(issuesJSON) }
        set { issuesJSON = Self.encode(newValue) }
    }

    var recommendations: [String] {
        get { Self.decode(recommendationsJSON) }
        set { recommendationsJSON = Self.encode(newValue) }
    }

    private static func decode(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private static func encode(_ values: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(values) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
