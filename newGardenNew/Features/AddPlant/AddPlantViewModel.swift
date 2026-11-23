import Foundation
import os
import SwiftData
import Observation
import UIKit

/// Backs the whole add-plant flow (M05-M08): camera, confirm, unrecognized, and seed. This
/// is the model behind P8 (5 steps -> 2) and P12/P13 (M07/M08). It stays a single ViewModel
/// because the steps share one draft; each View only reads the slice it needs.
@MainActor
@Observable
final class AddPlantViewModel {
    private let plantRepository: any PlantRepositoryProtocol
    private let plantNetService: any PlantNetServiceProtocol
    private let trefleService: (any TrefleServiceProtocol)?
    private let modelContext: ModelContext

    // Camera / identification state
    private(set) var isIdentifying = false
    private(set) var suggestions: [PlantNetResult] = []
    private(set) var identificationError: (any Error)?
    var capturedPhoto: Data?
    /// What PlantNet's own classifier read the captured photo as ("leaf", "flower", ...),
    /// and how confident it was. Surfaced in the confirm screen ("PlantNet la leyó como
    /// hoja") so the user — the only one who can see their own photo — can catch a
    /// misread organ before it sends the whole identification down the wrong path.
    private(set) var predictedOrgan: String?
    private(set) var predictedOrganScore: Double?

    // Confirm step
    var selectedSuggestionIndex: Int?
    var locationIndex = 0
    /// Static so `PlantEditView` can reuse the exact same four options (and their exact
    /// strings, which `WateringRuleEngine.exposureFactor` matches against) instead of a
    /// second, driftable copy.
    static let locationOptions: [(String, String)] = [
        (String(localized: "addPlant.location.indoorBright", defaultValue: "Interior luminoso"), "sun.max"),
        (String(localized: "addPlant.location.indoorDim", defaultValue: "Interior sombrío"), "cloud"),
        (String(localized: "addPlant.location.outdoorSun", defaultValue: "Exterior sol"), "sun.max.fill"),
        (String(localized: "addPlant.location.outdoorShade", defaultValue: "Exterior sombra"), "tree.fill"),
    ]
    var locationOptions: [(String, String)] { Self.locationOptions }

    // M07: unrecognized plant
    var nickname: String = ""
    var functionalGroup: FunctionalGroup = .tropicalIndoor
    var leafType = 0
    var sizeCategory = 1
    var freeNotes: String = ""
    var retryLaterEnabled = true

    // M08: seed sowing
    var seedName: String = ""
    var sowingMethod = 1
    var sownDate: Date = .now

    init(
        plantRepository: any PlantRepositoryProtocol,
        plantNetService: any PlantNetServiceProtocol,
        trefleService: (any TrefleServiceProtocol)? = nil,
        modelContext: ModelContext
    ) {
        self.plantRepository = plantRepository
        self.plantNetService = plantNetService
        self.trefleService = trefleService
        self.modelContext = modelContext
    }

    func identify(photo: Data) async {
        AppLog.checkpoint.notice("AddPlant: identify() started, photo size \(photo.count, privacy: .public) bytes")
        capturedPhoto = photo
        isIdentifying = true
        defer { isIdentifying = false }
        do {
            let response = try await plantNetService.identifyPlant(images: [photo])
            suggestions = Array(response.results.prefix(3))
            predictedOrgan = response.predictedOrgans?.first?.organ
            predictedOrganScore = response.predictedOrgans?.first?.score
            identificationError = nil
            // AddPlantConfirmView shows the top suggestion as visually selected whenever its
            // score is above 0.5, WITHOUT the user tapping anything — but tapping a row was
            // the only thing that ever set this. Found live: two plants saved in a row both
            // came out named "Mi planta" despite PlantNet returning 52%+ matches, because
            // `selectedSuggestionIndex` stayed nil and `saveConfirmed()` had nothing to read.
            // Match the view's own auto-select rule here so state and UI agree from the start.
            if let first = suggestions.first, first.score > 0.5 {
                selectedSuggestionIndex = 0
            }
            AppLog.checkpoint.notice("AddPlant: identify() got \(self.suggestions.count, privacy: .public) suggestions, auto-selected=\(self.selectedSuggestionIndex.map { "\($0)" } ?? "none", privacy: .public)")
        } catch {
            identificationError = error
            suggestions = []
            AppLog.plantData.error("Identification failed: \(error, privacy: .public)")
            AppLog.checkpoint.notice("AddPlant: identify() failed, degrading to manual entry — \(error, privacy: .public)")
        }
    }

    /// Saves a plant confirmed from PlantNet suggestions (M06). Everything but species and
    /// location is auto-filled and editable later — P8's "2 steps, not 5".
    func saveConfirmed() {
        let suggestion = selectedSuggestionIndex.flatMap { suggestions[safe: $0] }
        // Same fallback order as the row's own label (AddPlantConfirmView.speciesRow): common
        // name, then scientific name, and only then the generic default. Many PlantNet matches
        // — especially the lower-confidence ones — have no common name at all; jumping
        // straight to "Mi planta" for those threw away a real, useful name PlantNet DID give us.
        let plant = Plant(
            name: suggestion?.species.commonNames?.first
                ?? suggestion?.species.scientificName
                ?? String(localized: "addPlant.defaultName", defaultValue: "Mi planta"),
            species: suggestion?.species.scientificName,
            commonName: suggestion?.species.commonNames?.first,
            familyName: suggestion?.species.family?.scientificNameWithoutAuthor,
            photoData: capturedPhoto,
            sunRequirement: locationOptions[locationIndex].0,
            identificationConfidence: .identified
        )
        persist(plant)
        prefetchTrefleData(for: plant)
    }

    /// Fills the species-level "ficha botánica" right after identification, instead of
    /// fetching it live on every watering analysis (the same data, refetched over and over
    /// for no reason — see `WateringOrchestrator.resolveTrefle`, which now reads this cache
    /// first). Fire-and-forget: the plant is already saved and the sheet already dismissed
    /// by the time this completes, so it never blocks "Guardar planta".
    private func prefetchTrefleData(for plant: Plant) {
        guard let trefleService, let species = plant.species else { return }
        let searchName = WateringOrchestrator.trefleSearchName(from: species)
        Task {
            guard let firstMatch = try? await trefleService.searchSpecies(query: searchName).first,
                  let detail = try? await trefleService.getSpeciesDetail(id: firstMatch.id).data else {
                AppLog.checkpoint.notice("AddPlant: Trefle prefetch found nothing for \(searchName, privacy: .public)")
                return
            }
            plant.cacheTrefleData(id: firstMatch.id, data: detail)
            do {
                try modelContext.save()
                AppLog.checkpoint.notice("AddPlant: Trefle prefetched and cached for \(plant.id, privacy: .public), species id \(firstMatch.id, privacy: .public)")
            } catch {
                AppLog.app.error("Failed to save prefetched Trefle data: \(error, privacy: .public)")
            }
        }
    }

    /// M07: saves a plant with no species, profiled by functional group instead. This is
    /// what feeds `WateringRuleEngine`'s crop coefficient when the species is unknown.
    func saveUnrecognized() {
        let plant = Plant(
            name: nickname.isEmpty ? String(localized: "addPlant.defaultName", defaultValue: "Mi planta") : nickname,
            photoData: capturedPhoto,
            notes: freeNotes.isEmpty ? nil : freeNotes,
            identificationConfidence: .functionalGroup,
            functionalGroup: functionalGroup
        )
        persist(plant)
    }

    /// M08: saves a plant grown from seed with its first stage plan. This is the one flow
    /// that writes `StagePlan` rows — see docs/ANALISIS_IMPLEMENTACION.md section 4,
    /// decision 1.
    func saveSeed() {
        let plant = Plant(
            name: seedName.isEmpty ? String(localized: "addPlant.seedDefaultName", defaultValue: "Semillero") : seedName,
            growthStage: .sowing,
            sownAt: sownDate
        )
        modelContext.insert(plant)

        for stage in GrowthStage.allCases {
            let plan = StagePlan(
                stage: stage,
                startDay: stage.typicalDayRange.lowerBound,
                endDay: stage.typicalDayRange.upperBound == 9999 ? nil : stage.typicalDayRange.upperBound,
                wateringIntervalHours: stage.defaultIntervalHours,
                plant: plant
            )
            modelContext.insert(plan)
        }

        // Was `try? modelContext.save()`, swallowing the error in silence — exactly the M3
        // finding from the original audit (docs/REPORTE_ESTADO_Y_REDISENO.md). Every other
        // save path in this file goes through `persist(_:)`, which logs; this one skipped it
        // because it inserts the plant directly to attach the stage plans. Route the error
        // the same way instead of dropping it.
        do {
            try modelContext.save()
            AppLog.checkpoint.notice("AddPlant: seed plant saved with \(GrowthStage.allCases.count, privacy: .public) stage plans")
        } catch {
            AppLog.app.error("Failed to save seed plant: \(error, privacy: .public)")
            AppLog.checkpoint.notice("AddPlant: saveSeed() failed — \(error, privacy: .public)")
        }
    }

    private func persist(_ plant: Plant) {
        do {
            try plantRepository.insert(plant)
            AppLog.checkpoint.notice("AddPlant: plant saved, id \(plant.id, privacy: .public)")
        } catch {
            AppLog.app.error("Failed to save new plant: \(error, privacy: .public)")
            AppLog.checkpoint.notice("AddPlant: save FAILED — \(error, privacy: .public)")
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
