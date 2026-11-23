import Foundation

/// The substrate a plant is actually potted in, with its available water capacity (AWC): the
/// fraction of substrate volume that holds water a root can actually use, between field
/// capacity and permanent wilting point. Values and sources are from
/// docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 2 — a real literature review done
/// specifically to replace the single linear diameter-based reserve estimate in
/// `WateringRuleEngine` with something grounded in the actual substrate, not a guess.
///
/// Every case here has a real, cited academic source EXCEPT `.cactusSucculent`, which is
/// explicitly flagged as low confidence (a manufacturer estimate, not peer-reviewed) because
/// that research found no academic measurement of a finished cactus/succulent potting mix —
/// see `confidenceNote`. Never silently treat that value as equally reliable as the others.
enum SubstrateType: String, Sendable, CaseIterable, Codable {
    case peat
    case cocoCoir
    case pineBarkFresh
    case pineBarkAged
    case commercialMix
    case cactusSucculent

    /// Available water capacity, as a fraction of substrate volume (0...1). The middle of the
    /// range reported in the literature, per case below.
    var availableWaterCapacity: Double {
        switch self {
        case .peat: 0.30 // 25-35%, Yeager et al. 2007 / Carlile et al. 2015
        case .cocoCoir: 0.24 // 20-28%, Abad et al. 2005 via Carlile et al. 2015
        case .pineBarkFresh: 0.10 // ~9.8%, Harrelson et al. 2004 via Bilderback et al. 2005
        case .pineBarkAged: 0.26 // ~26.3%, same source — 2.7x more than fresh bark
        case .commercialMix: 0.30 // 23-37%, Bilderback et al. 2005 / UF IFAS AE562
        case .cactusSucculent: 0.25 // manufacturer estimate only, see confidenceNote
        }
    }

    var displayName: String {
        switch self {
        case .peat: String(localized: "substrate.peat", defaultValue: "Turba")
        case .cocoCoir: String(localized: "substrate.cocoCoir", defaultValue: "Fibra de coco")
        case .pineBarkFresh: String(localized: "substrate.pineBarkFresh", defaultValue: "Corteza de pino (fresca)")
        case .pineBarkAged: String(localized: "substrate.pineBarkAged", defaultValue: "Corteza de pino (añejada, 1 año o más)")
        case .commercialMix: String(localized: "substrate.commercialMix", defaultValue: "Mezcla comercial genérica para macetas")
        case .cactusSucculent: String(localized: "substrate.cactusSucculent", defaultValue: "Mezcla para cactus / suculentas")
        }
    }

    /// Non-nil only for the one case whose number isn't from peer-reviewed measurement.
    /// Surfaced in the UI wherever this substrate's AWC feeds a calculation, per the
    /// "reglas siempre calculan, pero con la incertidumbre a la vista" principle already used
    /// for pet toxicity and AI corrections elsewhere in the app.
    var confidenceNote: String? {
        switch self {
        case .cactusSucculent:
            String(
                localized: "substrate.cactusSucculent.confidenceNote",
                defaultValue: "Estimación de fabricante, no de un estudio revisado por pares. Trátala como punto de partida, no como un dato firme."
            )
        default:
            nil
        }
    }
}
