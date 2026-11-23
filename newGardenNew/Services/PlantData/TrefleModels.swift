import Foundation

// Ported verbatim in shape from the old codebase. `Prompts.buildWateringContext` (see
// Services/AI/Prompts.swift) reads these exact field names, so this stays untouched.

nonisolated struct TrefleSearchResult: Codable, Sendable { let data: [TreflePlant] }

nonisolated struct TreflePlant: Codable, Sendable, Identifiable {
    let id: Int
    let common_name: String?
    let scientific_name: String
    let family_common_name: String?
    let image_url: String?
}

nonisolated struct TrefleSpeciesSearchResult: Codable, Sendable { let data: [TrefleSpecies] }

nonisolated struct TrefleSpecies: Codable, Sendable, Identifiable {
    let id: Int
    let common_name: String?
    let scientific_name: String
    let family_common_name: String?
    let image_url: String?
    let genus: String?
    let family: String?
}

nonisolated struct TrefleSpeciesDetailResult: Codable, Sendable { let data: TrefleSpeciesFullData }

nonisolated struct TrefleSpeciesFullData: Codable, Sendable {
    let id: Int
    let common_name: String?
    let scientific_name: String
    let family_common_name: String?
    let image_url: String?
    let genus: FlexibleStringField?
    let family: FlexibleStringField?
    let observations: String?
    let edible_part: [String]?
    let edible: Bool?
    let vegetable: Bool?
    let growth: TrefleGrowth?
    let specifications: TrefleSpecifications?
    let flower: TrefleFlower?
    let foliage: TrefleFoliage?
    let fruit_or_seed: TrefleFruitOrSeed?
    let distribution: TrefleDistribution?
    let images: TrefleImages?
    let common_names: [String: [String]]?
    let duration: DurationValue?

    enum DurationValue: Codable, Sendable {
        case single(String)
        case multiple([String])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let arr = try? container.decode([String].self) { self = .multiple(arr) }
            else if let str = try? container.decode(String.self) { self = .single(str) }
            else { throw DecodingError.typeMismatch(DurationValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]")) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .single(let s): try container.encode(s)
            case .multiple(let arr): try container.encode(arr)
            }
        }

        var values: [String] {
            switch self {
            case .single(let s): [s]
            case .multiple(let arr): arr
            }
        }
    }
}

nonisolated enum FlexibleStringField: Codable, Sendable {
    case string(String)
    case object(name: String?)

    private struct NamedObject: Codable { let name: String? }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { self = .string(str) }
        else if let obj = try? container.decode(NamedObject.self) { self = .object(name: obj.name) }
        else { self = .object(name: nil) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .object(let name): try container.encode(NamedObject(name: name))
        }
    }

    var displayName: String? {
        switch self {
        case .string(let s): s
        case .object(let name): name
        }
    }
}

nonisolated struct TrefleGrowth: Codable, Sendable {
    let light: Int?
    let atmospheric_humidity: Int?
    let drought_tolerance: Bool?
    let minimum_temperature: TrefleMeasurement?
    let maximum_temperature: TrefleMeasurement?
    let minimum_precipitation: TrefleMeasurement?
    let maximum_precipitation: TrefleMeasurement?
    let ph_minimum: Double?
    let ph_maximum: Double?
    let soil_nutriments: Int?
    let soil_salinity: Int?
    let soil_texture: Int?
    let soil_humidity: Int?
    let spread: TrefleMeasurement?
    let minimum_root_depth: TrefleMeasurement?
    let row_spacing: TrefleMeasurement?
    let days_to_harvest: Int?
    let growth_months: [String]?
    let bloom_months: [String]?
    let fruit_months: [String]?
    let description: String?
    let sowing: String?
}

nonisolated struct TrefleMeasurement: Codable, Sendable {
    let mm: Double?
    let cm: Double?
    let deg_c: Double?
    let deg_f: Double?
}

nonisolated struct TrefleSpecifications: Codable, Sendable {
    let toxicity: String?
    let average_height: TrefleMeasurement?
    let maximum_height: TrefleMeasurement?
    let growth_rate: String?
    let growth_form: String?
    let growth_habit: String?
    let ligneous_type: String?
    let nitrogen_fixation: String?
    let shape_and_orientation: String?
}

nonisolated struct TrefleFlower: Codable, Sendable {
    let color: [String]?
    let conspicuous: Bool?
}

nonisolated struct TrefleFoliage: Codable, Sendable {
    let texture: String?
    let color: [String]?
    let leaf_retention: Bool?
}

nonisolated struct TrefleFruitOrSeed: Codable, Sendable {
    let conspicuous: Bool?
    let color: [String]?
    let shape: String?
    let seed_persistence: Bool?
}

nonisolated struct TrefleDistribution: Codable, Sendable {
    let native: [TrefleZone]?
    let introduced: [TrefleZone]?
}

nonisolated enum TrefleZone: Codable, Sendable {
    case name(String)
    case object(TrefleZoneObject)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { self = .name(str) }
        else if let obj = try? container.decode(TrefleZoneObject.self) { self = .object(obj) }
        else { self = .name("Unknown") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .name(let s): try container.encode(s)
        case .object(let o): try container.encode(o)
        }
    }

    var displayName: String {
        switch self {
        case .name(let s): s
        case .object(let o): o.name ?? "Unknown"
        }
    }
}

nonisolated struct TrefleZoneObject: Codable, Sendable {
    let id: Int?
    let name: String?
    let slug: String?
}

nonisolated struct TrefleImages: Codable, Sendable {
    let flower: [TrefleImageEntry]?
    let leaf: [TrefleImageEntry]?
    let habit: [TrefleImageEntry]?
    let fruit: [TrefleImageEntry]?
    let bark: [TrefleImageEntry]?
    let other: [TrefleImageEntry]?
}

nonisolated struct TrefleImageEntry: Codable, Sendable { let image_url: String? }
