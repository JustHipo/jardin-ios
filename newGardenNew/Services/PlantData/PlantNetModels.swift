import Foundation

struct PlantNetIdentifyResponse: Codable, Sendable {
    let bestMatch: String?
    let results: [PlantNetResult]
    let remainingIdentificationRequests: Int?
    /// Which organ PlantNet's own classifier thinks each uploaded photo shows, one entry per
    /// image sent. Not decorative: if the classifier misreads the organ (e.g. calls a
    /// whole-plant photo a "flower" shot, seen live on 2026-09-13), the whole identification
    /// is working from the wrong premise, and the user looking at their own photo is the
    /// only one who can catch that — this is what lets the UI say "PlantNet leyó esto como
    /// X" instead of silently trusting a possibly-wrong guess.
    let predictedOrgans: [PlantNetPredictedOrgan]?
}

struct PlantNetPredictedOrgan: Codable, Sendable {
    let image: String?
    let filename: String?
    /// "flower", "leaf", "habit", "fruit", "bark", "fruit", "other"...
    let organ: String?
    let score: Double?
}

struct PlantNetResult: Codable, Sendable {
    let score: Double
    let species: PlantNetSpecies
    /// Reference photos for this candidate, straight from the same `/v2/identify` call —
    /// no extra request, no Trefle dependency. Only present when the request opts in with
    /// `include-related-images=true` (see `PlantNetService`); absent otherwise, which is
    /// why this is optional rather than defaulting to an empty array. Verified live against
    /// the real API on 2026-09-13: PlantNet returns images matching the SAME organ its
    /// classifier assigned to the query photo (all "flower" for a whole-plant photo it read
    /// as a flower shot in one real test), not one of each organ as might be assumed from
    /// the field's shape alone — a single-photo upload will not reliably surface a mix of
    /// hoja/porte/flor/tallo references.
    let images: [PlantNetImage]?
}

/// One reference photo PlantNet holds for a species, plus the attribution its CC BY-SA
/// license requires. Cache `author`/`license`/`citation` alongside any locally-stored copy
/// of the image — the attribution must travel with the photo, not just live next to the URL.
struct PlantNetImage: Codable, Sendable {
    /// "flower", "leaf", "habit", "fruit", ... — the organ PlantNet's own classifier
    /// assigned to this reference photo, matching `predictedOrgans` in the raw response.
    let organ: String?
    let author: String?
    /// e.g. "cc-by-sa" (lowercase, as PlantNet sends it — not "CC BY-SA").
    let license: String?
    let date: PlantNetImageDate?
    let url: PlantNetImageURL
    /// Pre-formatted attribution string PlantNet itself recommends showing verbatim, e.g.
    /// "KP Laer / Pl@ntNet, cc-by-sa". Prefer this over hand-building one from the other
    /// fields — it's the wording PlantNet's own terms ask for.
    let citation: String?
}

struct PlantNetImageURL: Codable, Sendable {
    /// Original (full) size.
    let o: String?
    /// Medium size — the one to actually display; `o` can be several MB.
    let m: String?
    /// Small / thumbnail size.
    let s: String?
}

struct PlantNetImageDate: Codable, Sendable {
    /// Epoch milliseconds.
    let timestamp: Double?
    /// Human-readable, pre-localized to the request's `lang` parameter.
    let string: String?
}

struct PlantNetSpecies: Codable, Sendable {
    let scientificNameWithoutAuthor: String
    let scientificName: String
    let genus: PlantNetTaxon?
    let family: PlantNetTaxon?
    let commonNames: [String]?
}

struct PlantNetTaxon: Codable, Sendable {
    let scientificNameWithoutAuthor: String
    let scientificName: String
}

struct PlantNetDiseaseResponse: Codable, Sendable {
    let results: [PlantNetDiseaseResult]
    let remainingIdentificationRequests: Int?
}

struct PlantNetDiseaseResult: Codable, Sendable {
    let name: String
    let score: Double
    let description: String?
}

extension String {
    /// PlantNet's organ codes ("leaf", "flower", "fruit", "bark", "habit", "other") in
    /// Spanish, for the two places the UI needs to name one: the "PlantNet leyó esto como…"
    /// bar and each candidate's reference-photo header ("Hojas de esta especie, 5").
    var plantNetOrganLabel: String {
        switch self {
        case "leaf": String(localized: "plantNet.organ.leaf", defaultValue: "hoja")
        case "flower": String(localized: "plantNet.organ.flower", defaultValue: "flor")
        case "fruit": String(localized: "plantNet.organ.fruit", defaultValue: "fruto")
        case "bark": String(localized: "plantNet.organ.bark", defaultValue: "corteza")
        case "habit": String(localized: "plantNet.organ.habit", defaultValue: "porte")
        default: String(localized: "plantNet.organ.other", defaultValue: "planta")
        }
    }

    /// Same label, capitalized and pluralized for a section header: "Hojas de esta especie".
    var plantNetOrganLabelPlural: String {
        switch self {
        case "leaf": String(localized: "plantNet.organ.leaf.plural", defaultValue: "Hojas")
        case "flower": String(localized: "plantNet.organ.flower.plural", defaultValue: "Flores")
        case "fruit": String(localized: "plantNet.organ.fruit.plural", defaultValue: "Frutos")
        case "bark": String(localized: "plantNet.organ.bark.plural", defaultValue: "Cortezas")
        case "habit": String(localized: "plantNet.organ.habit.plural", defaultValue: "Porte")
        default: String(localized: "plantNet.organ.other.plural", defaultValue: "Fotos")
        }
    }
}
