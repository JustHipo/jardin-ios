import Foundation
import SwiftData

/// A plant the user is caring for.
///
/// Every property is optional or has a default, and every relationship is optional, because
/// CloudKit requires it. Do not add `@Attribute(.unique)` here for the same reason.
@Model
final class Plant {
    var id: UUID = UUID()
    var name: String = ""
    var species: String?
    var commonName: String?
    var familyName: String?
    var referenceImageURL: String?

    @Attribute(.externalStorage) var photoData: Data?

    // MARK: Watering

    var waterEveryDays: Int = 5
    /// Set by the AI when it adjusts the cycle. Nil means the base cycle is in effect.
    var waterEveryDaysAdjusted: Int?
    /// Fraction of the cycle after which the plant is reported as "soon".
    var soonAtPct: Double = 0.75

    var sunRequirement: String?
    var notes: String?
    /// Free text the user writes about light, pot and soil. Collected after saving, never before.
    var userContext: String?

    // MARK: Container

    var containerDiameterCm: Double?
    var containerType: String?
    var containerMaterial: String?
    /// How many individual plants share this same physical container (interplanting, several
    /// seedlings in one pot). Nil means "unknown", read as 1 (this plant alone) — never
    /// assume a crowded pot just because the field hasn't been filled in. The rule engine
    /// divides the container's water reserve by this count, since several plants draw down
    /// the same finite substrate water faster than one alone; nothing else in the model can
    /// correct for that; see `WateringRuleEngine.reserveDepth`.
    var containerPlantCount: Int?

    /// Real measured pot geometry (top diameter, bottom diameter, height), all optional and
    /// independent of `containerDiameterCm`. When all three are known, the rule engine computes
    /// the actual frustum volume of the pot instead of the old diameter-only proxy — see
    /// docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 1. Nil for any of the three means
    /// "not measured", not zero; the engine falls back to `containerDiameterCm` in that case.
    var containerTopDiameterCm: Double?
    var containerBottomDiameterCm: Double?
    var containerHeightCm: Double?

    /// Raw value of `SubstrateType`. Nil means "not specified" — the rule engine then uses a
    /// generic default available-water-capacity rather than any specific substrate's number.
    var substrateTypeRaw: String?

    /// Learned purely from real watering dates (never from photos or AI): how much to scale
    /// the rule engine's own cycle length for this specific plant. 1.0 means "no correction
    /// yet" (the default, and where every plant starts). See `WateringCalibration` and
    /// docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md sections 7 and 11.
    var waterCalibrationMultiplier: Double = 1.0

    // MARK: Growth stages (seed sowing, M08)

    /// Raw value of `GrowthStage`. Stored as String because CloudKit cannot hold Swift enums.
    var growthStageRaw: String?
    /// When the seed was sown. Nil for plants adopted already grown.
    var sownAt: Date?

    // MARK: Identification confidence

    /// Raw value of `IdentificationConfidence`. A plant added through the unrecognised flow
    /// (M07) carries `.functionalGroup`, which tells the rest of the app to be conservative.
    var identificationConfidenceRaw: String?
    /// Raw value of `FunctionalGroup` when the species is unknown but the group is not.
    var functionalGroupRaw: String?
    /// Raw value of `GrowthPhase` — the plant's current vigor (vegetativa/floración/
    /// fructificación/reposo), set by hand in `PlantEditView` or suggested from a health
    /// check's photo. Nil means "no idea", not "vegetativa" — never assume a default.
    var growthPhaseRaw: String?

    // MARK: Botanical enrichment

    var trefleId: Int?
    var trefleDetailJSON: String?

    // MARK: Pet safety
    //
    // Hard product requirement. Nil means "not yet known", which is different from `false`
    // and must never be rendered as "safe". See `PetSafetyVerdict`.

    var isToxicToDogs: Bool?
    var isToxicToCats: Bool?
    var toxicityNotes: String?

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \GardenNode.plant)
    var gardenNodes: [GardenNode]?

    @Relationship(deleteRule: .cascade, inverse: \WateringEvent.plant)
    var wateringEvents: [WateringEvent]?

    @Relationship(deleteRule: .cascade, inverse: \AIAnalysis.plant)
    var aiAnalyses: [AIAnalysis]?

    @Relationship(deleteRule: .cascade, inverse: \CareStep.plant)
    var careSteps: [CareStep]?

    @Relationship(deleteRule: .cascade, inverse: \PlantPhoto.plant)
    var photos: [PlantPhoto]?

    @Relationship(deleteRule: .cascade, inverse: \StagePlan.plant)
    var stagePlans: [StagePlan]?

    @Relationship(deleteRule: .cascade, inverse: \HealthCheck.plant)
    var healthChecks: [HealthCheck]?

    @Relationship(deleteRule: .cascade, inverse: \AIAuditEntry.plant)
    var aiAuditEntries: [AIAuditEntry]?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.plant)
    var chatMessages: [ChatMessage]?

    @Relationship(deleteRule: .cascade, inverse: \WateringCalibrationEvent.plant)
    var calibrationEvents: [WateringCalibrationEvent]?

    @Relationship(deleteRule: .cascade, inverse: \ET0CrossCheckEntry.plant)
    var et0CrossCheckEntries: [ET0CrossCheckEntry]?

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        species: String? = nil,
        commonName: String? = nil,
        familyName: String? = nil,
        referenceImageURL: String? = nil,
        photoData: Data? = nil,
        waterEveryDays: Int = 5,
        waterEveryDaysAdjusted: Int? = nil,
        soonAtPct: Double = 0.75,
        sunRequirement: String? = nil,
        notes: String? = nil,
        userContext: String? = nil,
        containerDiameterCm: Double? = nil,
        containerType: String? = nil,
        containerMaterial: String? = nil,
        containerPlantCount: Int? = nil,
        growthStage: GrowthStage? = nil,
        sownAt: Date? = nil,
        identificationConfidence: IdentificationConfidence? = nil,
        functionalGroup: FunctionalGroup? = nil,
        isToxicToDogs: Bool? = nil,
        isToxicToCats: Bool? = nil,
        toxicityNotes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.commonName = commonName
        self.familyName = familyName
        self.referenceImageURL = referenceImageURL
        self.photoData = photoData
        self.waterEveryDays = waterEveryDays
        self.waterEveryDaysAdjusted = waterEveryDaysAdjusted
        self.soonAtPct = soonAtPct
        self.sunRequirement = sunRequirement
        self.notes = notes
        self.userContext = userContext
        self.containerDiameterCm = containerDiameterCm
        self.containerType = containerType
        self.containerMaterial = containerMaterial
        self.containerPlantCount = containerPlantCount
        self.growthStageRaw = growthStage?.rawValue
        self.sownAt = sownAt
        self.identificationConfidenceRaw = identificationConfidence?.rawValue
        self.functionalGroupRaw = functionalGroup?.rawValue
        self.isToxicToDogs = isToxicToDogs
        self.isToxicToCats = isToxicToCats
        self.toxicityNotes = toxicityNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Typed access over the raw storage

extension Plant {
    /// Nil for a plant that is not being grown from seed.
    var growthStage: GrowthStage? {
        get { growthStageRaw.flatMap(GrowthStage.init(rawValue:)) }
        set { growthStageRaw = newValue?.rawValue }
    }

    /// Nil means "no idea" — never defaults to `.vegetative` just because that's first in
    /// the enum, same rule as pet toxicity.
    var growthPhase: GrowthPhase? {
        get { growthPhaseRaw.flatMap(GrowthPhase.init(rawValue:)) }
        set { growthPhaseRaw = newValue?.rawValue }
    }

    /// Nil means "not specified" — see `Plant.substrateTypeRaw`'s doc comment.
    var substrateType: SubstrateType? {
        get { substrateTypeRaw.flatMap(SubstrateType.init(rawValue:)) }
        set { substrateTypeRaw = newValue?.rawValue }
    }

    var identificationConfidence: IdentificationConfidence {
        get { identificationConfidenceRaw.flatMap(IdentificationConfidence.init(rawValue:)) ?? .unknown }
        set { identificationConfidenceRaw = newValue.rawValue }
    }

    var functionalGroup: FunctionalGroup? {
        get { functionalGroupRaw.flatMap(FunctionalGroup.init(rawValue:)) }
        set { functionalGroupRaw = newValue?.rawValue }
    }

    /// True when this plant follows a staged plan instead of a fixed cycle.
    var isGrownFromSeed: Bool { sownAt != nil }
}

// MARK: - Derived watering state

extension Plant {
    /// The cycle actually in effect: the AI adjustment when there is one, the base otherwise.
    var effectiveCycleDays: Int {
        waterEveryDaysAdjusted ?? waterEveryDays
    }

    var lastWateredAt: Date? {
        (wateringEvents ?? []).max(by: { $0.wateredAt < $1.wateredAt })?.wateredAt
    }

    /// Elapsed fraction of the current cycle. Nil when the plant has never been watered.
    var wateringProgress: Double? {
        guard let lastWateredAt else { return nil }
        let daysSince = Date.now.daysSince(lastWateredAt)
        return daysSince / Double(max(1, effectiveCycleDays))
    }

    var wateringStatus: WateringStatus {
        guard let progress = wateringProgress else { return .neverWatered }
        if progress < soonAtPct { return .ok }
        if progress < 1.0 { return .soon }
        return .overdue
    }

    /// Whole days until the next watering is due. Negative means overdue by that many days.
    var daysUntilDue: Int? {
        guard let lastWateredAt else { return nil }
        let due = Calendar.current.date(byAdding: .day, value: effectiveCycleDays, to: lastWateredAt) ?? lastWateredAt
        return due.calendarDaysSince(.now)
    }
}

enum WateringStatus: String, Sendable, CaseIterable {
    case neverWatered
    case ok
    case soon
    case overdue
}
