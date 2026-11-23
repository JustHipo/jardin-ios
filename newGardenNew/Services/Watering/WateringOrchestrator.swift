import Foundation
import os
import SwiftData
import WidgetKit

/// Ties the rule engine, the AI engine and the audit trail together for one plant's watering
/// adjustment. This is where the "reglas siempre, IA aditiva" split lives:
///
/// 1. The rule engine computes the baseline. Always. On every device.
/// 2. If an AI engine is available, it may propose a bounded correction (-2...+2 days) —
///    only applied when it declares high confidence AND gives a concrete visual reason.
/// 3. The audit trail records which engine actually answered, even when the AI step is
///    skipped or fails — the fallback is silent to the user but never silent to the log.
///    See docs/ANALISIS_IMPLEMENTACION.md section 3 and the exchange with mygarden-f9.
@MainActor
final class WateringOrchestrator {
    private let ruleEngine = WateringRuleEngine.self
    private let plantNetService: (any PlantNetServiceProtocol)?
    private let weatherProvider: (any WeatherProviding)?
    private let et0ReferenceProvider: (any ET0ReferenceProviding)?
    private let weatherCache: WeatherCache
    private let trefleService: (any TrefleServiceProtocol)?
    private let aiRouter: AIRouter
    private let modelContext: ModelContext
    private let settings: AppSettings

    init(
        plantNetService: (any PlantNetServiceProtocol)?,
        weatherProvider: (any WeatherProviding)?,
        et0ReferenceProvider: (any ET0ReferenceProviding)? = nil,
        weatherCache: WeatherCache,
        trefleService: (any TrefleServiceProtocol)?,
        aiRouter: AIRouter,
        modelContext: ModelContext,
        settings: AppSettings
    ) {
        self.plantNetService = plantNetService
        self.weatherProvider = weatherProvider
        self.et0ReferenceProvider = et0ReferenceProvider
        self.weatherCache = weatherCache
        self.trefleService = trefleService
        self.aiRouter = aiRouter
        self.modelContext = modelContext
        self.settings = settings
    }

    @discardableResult
    func analyzePlant(_ plant: Plant, newPhoto: Data? = nil) async throws -> AIAnalysis {
        let startTime = Date.now

        if let photoData = newPhoto {
            modelContext.insert(PlantPhoto(photoData: photoData, context: "analysis", plant: plant))
        }

        // 1. Weather: cache first, provider second, never blocking on failure.
        let weatherContext = await resolveWeather()

        // 2. Trefle, optional and cached per species — refines the crop coefficient.
        let trefleData = await resolveTrefle(for: plant)

        // 2b. Pet safety is a hard requirement (see `Plant.isToxicToDogs`'s doc comment): this
        // is the ONLY place anything ever set those fields, and until now nothing did — the
        // toxicity card showed "todavía no sabemos" forever, for every plant, because Trefle's
        // `specifications.toxicity` was read into the AI's context JSON but never copied onto
        // the model. Trefle reports one general level, not separate dog/cat verdicts, so a
        // conservative "not none means toxic to both" is the safest reading of it.
        if let toxicityLevel = trefleData?.specifications?.toxicity {
            let isToxic = toxicityLevel.lowercased() != "none"
            plant.isToxicToDogs = isToxic
            plant.isToxicToCats = isToxic
            plant.toxicityNotes = "Trefle reporta nivel de toxicidad \"\(toxicityLevel)\"."
        }

        // 3. The floor: the deterministic baseline, always computed.
        let (baseCropCoefficient, speciesSignal) = speciesCropCoefficient(trefle: trefleData, functionalGroup: plant.functionalGroup)
        // A mature plant's CURRENT phase (floración, fructificación...) shifts its water
        // demand well beyond what a species-level coefficient alone can say — Trefle has no
        // concept of "this specimen, right now" at all. See `GrowthPhase`'s doc comment for
        // the live case that surfaced this (a fruiting bean plant given the same generic 0.7
        // as any unclassified plant).
        let cropCoefficient = baseCropCoefficient * (plant.growthPhase?.cropCoefficientMultiplier ?? 1.0)

        // Read once, reused below for the AI context too — same record, not a second query.
        let healthCheck = lastHealthCheck(for: plant)
        let (healthModifier, healthSignal) = healthStressModifier(healthCheck)

        let ruleOutput = WateringRuleEngine.computeCycle(.init(
            containerDiameterCm: plant.containerDiameterCm,
            containerMaterial: plant.containerMaterial,
            sunRequirement: plant.sunRequirement,
            cropCoefficient: cropCoefficient,
            weather: weatherContext,
            latitude: settings.latitude,
            recentRainMm: weatherContext?.history.reduce(0) { $0 + $1.rainMm } ?? 0,
            containerPlantCount: plant.containerPlantCount,
            healthStressModifier: healthModifier,
            containerTopDiameterCm: plant.containerTopDiameterCm,
            containerBottomDiameterCm: plant.containerBottomDiameterCm,
            containerHeightCm: plant.containerHeightCm,
            substrateAWC: plant.substrateType?.availableWaterCapacity
        ))

        // Every input the rule engine actually used, in one line — this is what "44 días,
        // ¿de dónde salió eso?" needs. `containerDiameterCm`/`containerMaterial` showing `nil`
        // here (falling back to the 18cm/neutral defaults) is the signal that the missing
        // Editar/mejora-precisión fields, not the math, are what's driving a long cycle.
        AppLog.checkpoint.notice("""
            Watering rules for \(plant.id, privacy: .public): diameter=\(plant.containerDiameterCm.map { "\($0)" } ?? "nil (default 18cm)", privacy: .public)cm \
            material=\(plant.containerMaterial ?? "nil", privacy: .public) sun=\(plant.sunRequirement ?? "nil", privacy: .public) \
            plantsInContainer=\(plant.containerPlantCount.map { "\($0)" } ?? "nil (1)", privacy: .public) \
            baseCropCoefficient=\(baseCropCoefficient, privacy: .public) (\(speciesSignal, privacy: .public), functionalGroup=\(plant.functionalGroup.map { "\($0)" } ?? "nil", privacy: .public)) \
            growthPhase=\(plant.growthPhase.map { "\($0.rawValue) (x\($0.cropCoefficientMultiplier))" } ?? "nil (x1.0)", privacy: .public) \
            healthStress=\(healthSignal, privacy: .public) (x\(healthModifier, privacy: .public)) \
            -> cropCoefficient=\(cropCoefficient, privacy: .public) hasWeather=\(weatherContext != nil, privacy: .public) \
            -> et0=\(ruleOutput.et0MmPerDay, privacy: .public) mm/day x exposure=\(ruleOutput.exposureModifier, privacy: .public) x material=\(ruleOutput.materialModifier, privacy: .public) \
            -> dailyLoss=\(ruleOutput.dailyLossMmPerDay, privacy: .public) mm/day; reserve=\(ruleOutput.reserveMm, privacy: .public)mm (\(ruleOutput.usedRealGeometry ? "geometria real + sustrato" : "proxy por diametro", privacy: .public)) rain=\(ruleOutput.rainOffsetMm, privacy: .public)mm -> effectiveReserve=\(ruleOutput.effectiveReserveMm, privacy: .public)mm \
            -> rawDays=\(ruleOutput.rawDays, privacy: .public) -> \(ruleOutput.cycleDays, privacy: .public) days (base rule engine, before calibration/IA)
            """)

        // Calibration: a per-plant multiplier learned purely from real watering dates (never
        // from photos or AI inference — see docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md
        // section 11.1). Applied on top of the rule engine's own output, distinct from and
        // always logged separately from the bounded AI correction below.
        let calibratedDays = WateringCalibration.applyMultiplier(plant.waterCalibrationMultiplier, toCycleDays: ruleOutput.cycleDays)
        if plant.waterCalibrationMultiplier != 1.0 {
            AppLog.checkpoint.notice("""
                Watering calibration for \(plant.id, privacy: .public): multiplier=\(plant.waterCalibrationMultiplier, privacy: .public) \
                (learned from real watering dates) -> \(ruleOutput.cycleDays, privacy: .public) days -> \(calibratedDays, privacy: .public) days
                """)
        }

        recordAudit(task: .wateringAdjustment, engine: .ruleEngine, plant: plant, succeeded: true, sources: sourceList(weather: weatherContext, trefle: trefleData))

        // Validation only, never fed back into the calculation: logs how far our own hand-rolled
        // Penman-Monteith ET0 is from Open-Meteo's, so a future formula bug (like the reserve
        // one this file already had) shows up in the log instead of staying silent. Best-effort:
        // no network, no key, no location, or a slow response never blocks or changes the result
        // the user sees. See docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md section 9.1.
        await crossCheckET0(ownEt0: ruleOutput.et0MmPerDay, plant: plant)

        // 4. Optional AI correction, bounded and additive — never authoritative on its own.
        var correction: WateringCorrection?
        var aiEngineUsed: AIEngineKind = .ruleEngine
        var fallbackReason: String?

        let recentPhotos: [Data] = (plant.photos ?? [])
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(3)
            .compactMap { $0.photoData }

        if !recentPhotos.isEmpty {
            let contextJSON = Prompts.buildWateringContext(
                plant: plant,
                ruleBaselineDays: calibratedDays,
                weather: weatherContext,
                trefle: trefleData,
                photoCount: recentPhotos.count,
                hasPets: settings.hasPets,
                petType: settings.petType?.rawValue,
                lastHealthCheck: healthCheck
            )

            // Try every candidate in order, falling through on failure — the same fix as
            // the chat path (AIRouter.wateringEngineCandidates' doc comment): "available"
            // only means the engine looked ready before generation was actually attempted.
            var lastError: (any Error)?
            for (result, engine) in await aiRouter.wateringEngineCandidates() {
                do {
                    correction = try await result.proposeWateringCorrection(
                        plant: plant, ruleBaselineDays: calibratedDays, context: contextJSON, recentPhotos: recentPhotos
                    )
                    aiEngineUsed = engine
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    AppLog.watering.notice("Watering correction failed on \(String(describing: engine), privacy: .public), trying next: \(error, privacy: .public)")
                }
            }
            if let lastError {
                fallbackReason = "AI correction unavailable: \(lastError.localizedDescription)"
                AppLog.watering.notice("Watering correction skipped, using rule baseline only: \(lastError, privacy: .public)")
            }
        }

        recordAudit(task: .wateringAdjustment, engine: aiEngineUsed, plant: plant, succeeded: correction != nil, fallbackReason: fallbackReason)

        // 5. Combine: calibrated baseline plus AI correction only if it earns its place.
        let appliedCorrection = (correction?.shouldApply == true) ? correction!.days : 0
        let finalCycle = max(WateringRuleEngine.minCycleDays, min(WateringRuleEngine.maxCycleDays, calibratedDays + appliedCorrection))

        let analysis = AIAnalysis(
            durationMs: Int(Date.now.timeIntervalSince(startTime) * 1000),
            ruleBaselineDays: calibratedDays,
            aiCorrectionDays: appliedCorrection == 0 ? nil : appliedCorrection,
            adjustDays: finalCycle - plant.waterEveryDays,
            confidence: correction?.confidence ?? "n/a",
            reasoning: correction?.reasoning ?? templatedReasoning(baseline: calibratedDays, weather: weatherContext, containerDiameterCm: plant.containerDiameterCm),
            plantProfile: correction?.plantProfile,
            environmentalFactors: correction?.environmentalFactors,
            riskAssessment: correction?.riskAssessment,
            wateringTip: correction?.wateringTip,
            plant: plant
        )
        modelContext.insert(analysis)

        plant.waterEveryDaysAdjusted = finalCycle
        plant.updatedAt = .now
        try modelContext.save()
        WidgetCenter.shared.reloadTimelines(ofKind: GardenWidgetKind.identifier)

        return analysis
    }

    /// Deterministic explanation when there's no AI narration — the template is written
    /// first and the model only ever improves on it, per the design agreement.
    private func templatedReasoning(baseline: Int, weather: WeatherContext?, containerDiameterCm: Double?) -> String {
        var text: String
        if let weather, weather.current.rainMm > 0 {
            text = "Cada \(baseline) días. Hubo lluvia reciente, así que el ciclo se alarga."
        } else if let weather, weather.current.tempC > 30 {
            text = "Cada \(baseline) días. Con este calor, la planta pierde agua más rápido."
        } else {
            text = "Cada \(baseline) días, calculado con el clima y la maceta de esta planta."
        }
        // A small pot holds little reserve and dries unevenly depending on exactly where the
        // roots sit, so the model's own precision has a real ceiling here regardless of how
        // good its other inputs are — the finger/soil test is the standard professional
        // fallback for exactly this case, and hiding that uncertainty would be dishonest.
        if let diameter = containerDiameterCm, diameter <= Self.smallPotDiameterCm {
            text += " Como la maceta es chica, revisa la tierra con el dedo antes de regar: si está húmeda unos centímetros abajo, espera un poco más."
        }
        // The engine only ever answers "cuándo", never "cuánto" — see
        // docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md section 9.4. Shown once a month
        // (day 1), not every time, since it's a maintenance reminder, not a per-watering
        // instruction: deterministic on the calendar, so it needs no new stored state.
        if Calendar.current.component(.day, from: .now) == 1 {
            text += " De vez en cuando riega despacio hasta que veas que sale un poco de agua por los agujeros de abajo: eso evita que se acumulen sales en la tierra."
        }
        return text
    }

    private static let smallPotDiameterCm: Double = 20

    /// A per-species crop coefficient from whichever Trefle signal is actually populated,
    /// tried in order from most to least direct. Two flat booleans (`drought_tolerance`,
    /// `vegetable`) used to be the whole story, which is why unrelated species with neither
    /// field set all collapsed to the same 0.7 default and the same cycle length — found
    /// live, comparing plants side by side. `soil_humidity` and precipitation range are
    /// numeric habitat data Trefle already returns and are populated far more often (see
    /// docs/ANALISIS_IMPLEMENTACION.md's live Trefle audit), so they go first and give a
    /// continuous value instead of 2-3 fixed buckets. Returns the coefficient plus a short
    /// tag naming which signal was used, for the checkpoint log.
    private func speciesCropCoefficient(trefle: TrefleSpeciesFullData?, functionalGroup: FunctionalGroup?) -> (Double, String) {
        if let soilHumidity = trefle?.growth?.soil_humidity {
            // Trefle's 0-10 habitat-preference scale for substrate moisture: 0 is
            // drought-adapted, 10 is a bog/aquatic plant. Mapped linearly onto the same
            // 0.4...1.4 range the old fixed buckets spanned.
            let coefficient = 0.4 + (Double(soilHumidity) / 10.0)
            return (coefficient, "soilHumidity=\(soilHumidity)")
        }
        if let minP = trefle?.growth?.minimum_precipitation?.mm, let maxP = trefle?.growth?.maximum_precipitation?.mm, (minP + maxP) > 0 {
            // Annual precipitation range (mm/yr) the species tolerates in the wild, averaged
            // and scaled against ~800mm/yr (a typical temperate total) as the Kc=1.0 point.
            let avgMm = (minP + maxP) / 2
            let coefficient = min(1.4, max(0.4, avgMm / 800))
            return (coefficient, "precipitationMm=\(Int(avgMm))")
        }
        if trefle?.growth?.drought_tolerance == true {
            return (0.4, "droughtTolerant=true")
        }
        if trefle?.vegetable == true {
            let coefficient = max(1.0, functionalGroup?.cropCoefficient ?? 1.0)
            return (coefficient, "vegetable=true")
        }
        let coefficient = functionalGroup?.cropCoefficient ?? 0.7
        return (coefficient, "noSpeciesData,functionalGroup=\(functionalGroup.map { "\($0)" } ?? "nil")")
    }

    /// Water-stress signs visible in the plant's own last health check, read as a
    /// deterministic multiplier — no live AI call needed, since the check's findings are
    /// already stored (whether they came from an AI diagnosis or the templated fallback).
    /// Distinct from `WateringCorrection`'s live, AI-proposed ±2 day nudge: this applies
    /// even when no AI engine is available right now, because it's just reading data, not
    /// re-interpreting a photo.
    private static let waterStressKeywords = [
        "marchit", "hojas caídas", "hojas caidas", "falta de agua", "deshidrat", "seca", "sequía", "sequedad",
    ]
    private static let overwaterKeywords = [
        "exceso de riego", "encharcad", "pudrición", "pudricion", "raíz podrida", "raiz podrida", "moho", "hongo",
    ]

    private func healthStressModifier(_ check: HealthCheck?) -> (Double, String) {
        guard let check else { return (1.0, "noCheck") }
        let text = ((check.diagnosis ?? "") + " " + check.issues.joined(separator: " ")).lowercased()
        if Self.overwaterKeywords.contains(where: text.contains) {
            return (0.75, "overwaterSignsInLastCheck")
        }
        if Self.waterStressKeywords.contains(where: text.contains) {
            return (1.3, "waterStressSignsInLastCheck")
        }
        if let score = check.healthScore, score <= 4 {
            return (1.15, "lowHealthScore=\(score)")
        }
        return (1.0, "noStressSignsInLastCheck")
    }

    /// Same context builder the watering correction sends the model — reused by the chat
    /// (M04) so the "6 sources" are the SAME data in both places, not a second, thinner
    /// summary. Returns the exact JSON handed to the LLM, logged in full so it's inspectable
    /// during testing (what pot size, location, Trefle data actually went out).
    func buildContextJSON(for plant: Plant) async -> String {
        let weatherContext = await resolveWeather()
        let trefleData = await resolveTrefle(for: plant)
        let json = Prompts.buildWateringContext(
            plant: plant,
            ruleBaselineDays: plant.effectiveCycleDays,
            weather: weatherContext,
            trefle: trefleData,
            photoCount: (plant.photos ?? []).count,
            hasPets: settings.hasPets,
            petType: settings.petType?.rawValue,
            lastHealthCheck: lastHealthCheck(for: plant)
        )
        AppLog.checkpoint.notice("Chat context for \(plant.id, privacy: .public), \(json.count, privacy: .public) chars:\n\(json, privacy: .public)")
        return json
    }

    /// Reads the cache `AddPlantViewModel` fills right after identification first — Trefle's
    /// data is per-species, not per-analysis, so refetching it on every "Recalcular" was
    /// always redundant. Plants added before this existed just fetch-and-cache themselves
    /// the first time they're analyzed here, same as any species lookup miss.
    private func resolveTrefle(for plant: Plant) async -> TrefleSpeciesFullData? {
        if let cached = plant.cachedTrefleData {
            AppLog.checkpoint.notice("Trefle: using cached data for \(plant.id, privacy: .public)")
            return cached
        }
        guard let trefleService, let species = plant.species else { return nil }
        guard let firstMatch = try? await trefleService.searchSpecies(query: Self.trefleSearchName(from: species)).first else { return nil }
        guard let detail = try? await trefleService.getSpeciesDetail(id: firstMatch.id).data else { return nil }
        plant.cacheTrefleData(id: firstMatch.id, data: detail)
        return detail
    }

    /// PlantNet returns the full taxonomic citation ("Citrus japonica Thunb.", "Sanguisorba
    /// alpina Bunge") but Trefle's search only matches the bare binomial — the author suffix
    /// makes it return zero results every time, silently degrading every Trefle-enriched
    /// field (crop coefficient, drought tolerance, toxicity) for every real identification.
    /// Found live: "Citrus japonica Thunb." → 0 matches, "Citrus japonica" → 1 real match.
    static func trefleSearchName(from species: String) -> String {
        let words = species.split(separator: " ")
        guard words.count > 2 else { return species }
        // A hybrid marker ("×"/"x") is part of the name, not the authority — keep 3 words then.
        if words[1] == "×" || words[1] == "x" {
            return words.prefix(3).joined(separator: " ")
        }
        return words.prefix(2).joined(separator: " ")
    }

    private func crossCheckET0(ownEt0: Double, plant: Plant) async {
        guard let et0ReferenceProvider, let lat = settings.latitude, let lon = settings.longitude else { return }
        do {
            let referenceEt0 = try await et0ReferenceProvider.fetchReferenceET0(latitude: lat, longitude: lon)
            let deltaPct = referenceEt0 > 0 ? (ownEt0 - referenceEt0) / referenceEt0 * 100 : 0
            AppLog.checkpoint.notice("""
                ET0 cross-check for \(plant.id, privacy: .public): propio=\(ownEt0, privacy: .public) mm/día \
                Open-Meteo=\(referenceEt0, privacy: .public) mm/día diferencia=\(deltaPct, privacy: .public)%
                """)
            // Persisted, not just logged — see `ET0CrossCheckEntry`'s doc comment: os_log isn't
            // a place either of us can review a trend in over weeks. Read by the Dashboard tab.
            modelContext.insert(ET0CrossCheckEntry(
                ownEt0MmPerDay: ownEt0, referenceEt0MmPerDay: referenceEt0, deltaPct: deltaPct, plant: plant
            ))
        } catch {
            AppLog.checkpoint.notice("ET0 cross-check skipped for \(plant.id, privacy: .public): \(error, privacy: .public)")
        }
    }

    private func resolveWeather() async -> WeatherContext? {
        if let cached = await weatherCache.getCached() { return cached }
        guard let weatherProvider, let lat = settings.latitude, let lon = settings.longitude else { return nil }
        guard let fresh = try? await weatherProvider.fetchWeather(latitude: lat, longitude: lon) else { return nil }
        let history = await weatherCache.getHistory()
        let withHistory = WeatherContext(current: fresh.current, history: history, forecast: fresh.forecast, season: fresh.season, cityName: fresh.cityName)
        await weatherCache.store(withHistory)
        return withHistory
    }

    private func lastHealthCheck(for plant: Plant) -> HealthCheck? {
        let plantId = plant.id
        let descriptor = FetchDescriptor<HealthCheck>(
            predicate: #Predicate { $0.plant?.id == plantId },
            sortBy: [SortDescriptor(\.checkedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func sourceList(weather: WeatherContext?, trefle: TrefleSpeciesFullData?) -> [String] {
        var sources = ["Tu historial"]
        if weather != nil { sources.append("WeatherKit") }
        if trefle != nil { sources.append("Trefle") }
        return sources
    }

    private func recordAudit(task: AITaskKind, engine: AIEngineKind, plant: Plant, succeeded: Bool, fallbackReason: String? = nil, sources: [String] = []) {
        let entry = AIAuditEntry(task: task, engine: engine, succeeded: succeeded, fallbackReason: fallbackReason, sourcesUsed: sources, plant: plant)
        modelContext.insert(entry)
    }
}
