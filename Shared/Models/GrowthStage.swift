import Foundation

/// The stage a plant grown from seed is in. Nil `Plant.growthStage` means the plant was
/// adopted already grown and follows a fixed cycle instead of a staged plan (M08).
enum GrowthStage: String, Sendable, CaseIterable, Codable {
    case sowing        // Siembra: substrate constantly moist
    case germination    // Germinación: misted twice a day
    case seedling       // Plántula: watered every 2 days
    case transplanted   // Trasplante: watered every 3 days, final pot

    var label: String {
        switch self {
        case .sowing: String(localized: "growthStage.sowing", defaultValue: "Siembra")
        case .germination: String(localized: "growthStage.germination", defaultValue: "Germinación")
        case .seedling: String(localized: "growthStage.seedling", defaultValue: "Plántula")
        case .transplanted: String(localized: "growthStage.transplanted", defaultValue: "Trasplante")
        }
    }

    /// Typical day range since sowing, used to suggest (never force) a stage transition.
    var typicalDayRange: ClosedRange<Int> {
        switch self {
        case .sowing: 0...3
        case .germination: 4...10
        case .seedling: 11...25
        case .transplanted: 26...9999
        }
    }

    /// Watering interval while in this stage, in hours. Germination waters twice a day.
    var defaultIntervalHours: Int {
        switch self {
        case .sowing: 24
        case .germination: 12
        case .seedling: 48
        case .transplanted: 72
        }
    }

    var next: GrowthStage? {
        switch self {
        case .sowing: .germination
        case .germination: .seedling
        case .seedling: .transplanted
        case .transplanted: nil
        }
    }
}

/// How confident the app is in a plant's species identification.
enum IdentificationConfidence: String, Sendable, CaseIterable, Codable {
    /// Species identified by PlantNet or the AI, with a real confidence score.
    case identified
    /// Species unknown, but the user described a functional group (M07).
    case functionalGroup
    /// No information at all yet.
    case unknown
}

/// A botanical functional group, used when the species is not known. Predicts watering
/// behavior better than the species name for a user who cannot identify it (see M07 and the
/// water balance engine, which uses this as its crop coefficient).
enum FunctionalGroup: String, Sendable, CaseIterable, Codable {
    case succulent          // Suculenta o cactus
    case tropicalIndoor     // Tropical de interior
    case aromaticEdible     // Aromática o comestible
    case outdoorShrub       // Arbusto o exterior
    case unknown            // No sabría decir

    var label: String {
        switch self {
        case .succulent: String(localized: "functionalGroup.succulent", defaultValue: "Suculenta o cactus")
        case .tropicalIndoor: String(localized: "functionalGroup.tropicalIndoor", defaultValue: "Tropical de interior")
        case .aromaticEdible: String(localized: "functionalGroup.aromaticEdible", defaultValue: "Aromática o comestible")
        case .outdoorShrub: String(localized: "functionalGroup.outdoorShrub", defaultValue: "Arbusto o exterior")
        case .unknown: String(localized: "functionalGroup.unknown", defaultValue: "No sabría decir")
        }
    }

    var symbol: String {
        switch self {
        case .succulent: "drop.triangle"
        case .tropicalIndoor: "leaf.fill"
        case .aromaticEdible: "fork.knife"
        case .outdoorShrub: "tree.fill"
        case .unknown: "questionmark.circle"
        }
    }

    /// Crop coefficient (Kc) for the water balance engine. Conservative middle-of-range
    /// values; refined per-species data from Trefle overrides this when available.
    var cropCoefficient: Double {
        switch self {
        case .succulent: 0.3
        case .tropicalIndoor: 0.8
        case .aromaticEdible: 0.9
        case .outdoorShrub: 0.7
        case .unknown: 0.6
        }
    }
}

/// Where a MATURE plant is in its cycle right now — vegetative growth, flowering, fruiting,
/// or dormant. Unrelated to `GrowthStage` (which tracks a seed-grown plant's age since
/// sowing): this is about a grown plant's current vigor, which Trefle has no concept of at
/// all (it describes the species in general, never one specimen's present state) and which
/// no other signal in this app captures. Found live: a bean plant photographed mid-fruiting
/// (pods fully formed) got the same generic crop coefficient as any unclassified plant,
/// because neither Trefle's sparse `drought_tolerance` nor a `FunctionalGroup` (only ever
/// set for M07's "unrecognized" flow) had anything specific to say about it.
enum GrowthPhase: String, Sendable, CaseIterable, Codable {
    case vegetative   // Creciendo: normal leaf/stem growth
    case flowering    // Floración: budding and blooming
    case fruiting     // Fructificación/cosecha: peak water demand
    case dormant      // Reposo: little to no active growth

    var label: String {
        switch self {
        case .vegetative: String(localized: "growthPhase.vegetative", defaultValue: "Creciendo")
        case .flowering: String(localized: "growthPhase.flowering", defaultValue: "Floración")
        case .fruiting: String(localized: "growthPhase.fruiting", defaultValue: "Fructificación")
        case .dormant: String(localized: "growthPhase.dormant", defaultValue: "En reposo")
        }
    }

    /// Multiplier over the base crop coefficient — FAO-56's own approach to adjusting a
    /// crop's water demand by growth stage, rather than a full per-species Kc table this app
    /// has no way to maintain. Peak demand at fruiting, minimal while dormant.
    var cropCoefficientMultiplier: Double {
        switch self {
        case .vegetative: 1.0
        case .flowering: 1.15
        case .fruiting: 1.3
        case .dormant: 0.5
        }
    }
}
