import Foundation

/// Deterministic watering calculation: a water balance, not a bag of if/else. Runs on every
/// device, always — this is the floor that Foundation Models sits on top of, not a fallback
/// for when it's missing. See docs/ANALISIS_IMPLEMENTACION.md section 3 for why this exists
/// and why the AI is never allowed to be the only source of the number.
///
/// The model: reserve (substrate volume) drains at a rate set by evapotranspiration (ET0,
/// FAO-56 Penman-Monteith) scaled by a crop coefficient (Kc) and an exposure modifier, and
/// refills with registered waterings and real rain. The cycle length is the number of days
/// it takes the reserve to drop from full to the point a plant of this kind should be
/// watered again.
///
/// This is intentionally testable with plain asserts — no model, no network, pure functions.
enum WateringRuleEngine {

    struct Input {
        /// Pot diameter in cm. Falls back to a medium default (18 cm) when unknown.
        let containerDiameterCm: Double?
        /// "terracotta", "plastic", "ceramic", ... Terracotta evaporates faster.
        let containerMaterial: String?
        /// "full sun", "partial shade", "indirect light", "low light"
        let sunRequirement: String?
        /// The crop coefficient. From `FunctionalGroup.cropCoefficient` when species is
        /// unknown, refined by Trefle's drought tolerance / soil humidity when known.
        let cropCoefficient: Double
        /// Recent weather: today plus forecast, used for ET0 and expected rain.
        let weather: WeatherContext?
        /// Latitude, needed for extraterrestrial radiation in the Penman-Monteith formula.
        let latitude: Double?
        /// Real rainfall recorded in the last few days (mm), separate from forecast.
        let recentRainMm: Double
        /// How many individual plants share this container. Nil or 1 means this plant has
        /// the whole reserve to itself. Several plants (interplanting, multiple seedlings in
        /// one pot) draw down the same finite substrate water faster than one alone — found
        /// live: a 30cm pot with several bean plants plus lentils computed 13 days assuming
        /// sole ownership of the reserve, when the real depletion rate is several times that.
        let containerPlantCount: Int?
        /// A multiplier on daily water loss from the plant's own last health check — visible
        /// wilting/dry soil raises it (loses water faster than the model alone would predict),
        /// visible overwatering/rot signs lower it. 1.0 when there's no check or nothing
        /// stands out. This is separate from, and always applied before, any live AI
        /// correction: it reads a stored diagnosis deterministically, the same on every
        /// device, rather than asking a model to re-judge it. See
        /// `WateringOrchestrator.healthStressModifier`.
        let healthStressModifier: Double

        /// Real measured pot geometry — top diameter, bottom diameter, height, all in cm.
        /// When all three are present, the engine computes the actual frustum volume of the
        /// pot instead of the diameter-only proxy below. See
        /// docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 1: there is no validated
        /// "root zone fraction" to further multiply this by, the frustum volume times the
        /// substrate's own available water capacity is already the right number to use.
        let containerTopDiameterCm: Double?
        let containerBottomDiameterCm: Double?
        let containerHeightCm: Double?
        /// The substrate's available water capacity as a fraction of volume (0...1), from
        /// `SubstrateType.availableWaterCapacity`. Only used when the three geometry fields
        /// above are also present; defaults to `Self.defaultAvailableWaterCapacity` when
        /// geometry is known but substrate isn't.
        let substrateAWC: Double?

        static let defaultContainerDiameterCm: Double = 18
        /// The general "normal range" midpoint for container substrates (23-37% AWC per
        /// Bilderback et al. 2005 / UF IFAS AE562), used only when real geometry is known but
        /// the specific substrate isn't — better than refusing to use the geometry at all.
        static let defaultAvailableWaterCapacity: Double = 0.28

        /// Explicit init, rather than relying on the synthesized memberwise one, so newer
        /// fields can default to their neutral values (nil == "not measured") for call sites,
        /// including the pre-existing tests, that predate them.
        init(
            containerDiameterCm: Double?,
            containerMaterial: String?,
            sunRequirement: String?,
            cropCoefficient: Double,
            weather: WeatherContext?,
            latitude: Double?,
            recentRainMm: Double,
            containerPlantCount: Int? = nil,
            healthStressModifier: Double = 1.0,
            containerTopDiameterCm: Double? = nil,
            containerBottomDiameterCm: Double? = nil,
            containerHeightCm: Double? = nil,
            substrateAWC: Double? = nil
        ) {
            self.containerDiameterCm = containerDiameterCm
            self.containerMaterial = containerMaterial
            self.sunRequirement = sunRequirement
            self.cropCoefficient = cropCoefficient
            self.weather = weather
            self.latitude = latitude
            self.recentRainMm = recentRainMm
            self.containerPlantCount = containerPlantCount
            self.healthStressModifier = healthStressModifier
            self.containerTopDiameterCm = containerTopDiameterCm
            self.containerBottomDiameterCm = containerBottomDiameterCm
            self.containerHeightCm = containerHeightCm
            self.substrateAWC = substrateAWC
        }
    }

    /// Substrate available-water-capacity per cm of pot diameter, in mm of reserve depth.
    /// A 20cm pot with ordinary potting mix holds roughly 45-50mm of plant-available water,
    /// not the ~90mm the old `diameterCm * 4.5` implied — that value was overestimating
    /// small-pot reserve by roughly 2x, which is why a 20cm pot of beans (which should be
    /// watered every 2-3 days per real horticultural guidance) was coming out at 28-36 days.
    /// See docs/ANALISIS_IMPLEMENTACION.md's live Trefle/PlantNet audit for the derivation.
    private static let reserveDepthPerCm: Double = 2.2

    /// Sea level, since neither WeatherKit nor WeatherAPI hand us the plant's elevation and
    /// the app doesn't collect it. Elevation only enters Penman-Monteith through atmospheric
    /// pressure (the psychrometric constant) and clear-sky radiation — a second-order effect
    /// at the range of elevations a houseplant is realistically kept at, and a much smaller
    /// error source than the reserve/wind/Kc bugs this file already had.
    private static let assumedElevationM: Double = 0

    struct Output {
        /// The computed cycle length in days. Clamped to a sane range so a bad input never
        /// produces an unusable recommendation.
        let cycleDays: Int
        /// Reference evapotranspiration (mm/day), before any Kc or modifier is applied. This
        /// used to be what this field held under the name `et0MmPerDay` while actually
        /// carrying `dailyLossMm` (Kc and modifiers already folded in) — a mislabeling that
        /// meant nothing external could ever be cross-checked against real ET0. Fixed as part
        /// of instrumenting the engine for the Open-Meteo cross-check (see
        /// docs/ANALISIS_ALGORITMO_RIEGO_REVISION_EXTERNA.md section 9.1).
        let et0MmPerDay: Double
        /// Daily water loss from the pot after Kc and every modifier (exposure, material,
        /// health stress) is applied. What the old, mislabeled `et0MmPerDay` actually held.
        let dailyLossMmPerDay: Double
        /// The exposure and material multipliers actually used, kept for the audit trail so
        /// a long cycle can be explained without recomputing the whole function by hand.
        let exposureModifier: Double
        let materialModifier: Double
        /// Reserve depth (mm) before splitting between plants sharing the container, and the
        /// rain offset folded into it.
        let reserveMm: Double
        let rainOffsetMm: Double
        /// The reserve actually used for this plant, after the rain offset and the split
        /// between however many plants share the container.
        let effectiveReserveMm: Double
        /// The unclamped division result, before rounding and clamping to [minCycleDays,
        /// maxCycleDays] — useful to tell "the math wanted 95 days but got clamped to 60"
        /// apart from "the math actually wanted 60".
        let rawDays: Double
        /// True when `reserveMm` came from real measured geometry + substrate AWC instead of
        /// the diameter-only proxy. Surfaced so the dashboard/log can show which plants are
        /// still running on the rough estimate versus the one backed by real measurements.
        let usedRealGeometry: Bool
    }

    static let minCycleDays = 1
    static let maxCycleDays = 60

    static func computeCycle(_ input: Input) -> Output {
        let et0 = estimateET0(weather: input.weather, latitude: input.latitude)
        let exposureModifier = exposureFactor(sunRequirement: input.sunRequirement)
        let materialModifier = materialFactor(containerMaterial: input.containerMaterial)

        // Daily water loss from the pot, in mm-equivalent over the substrate's surface.
        // Wind is no longer a separate bucketed multiplier here — Penman-Monteith already
        // folds it into `et0` itself via the aerodynamic term.
        let dailyLossMm = max(0.1, et0 * input.cropCoefficient * exposureModifier * materialModifier * input.healthStressModifier)

        // Reserve: how much water the substrate holds when fully watered, as a depth in mm
        // over its own surface. When real geometry is known, this is the actual frustum
        // volume of the pot times the substrate's real available water capacity, converted
        // back to mm-over-surface (liters / m² of top opening == mm, an exact unit identity —
        // this is why the rest of the formula below didn't need to change at all). See
        // docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md sections 1-2. Otherwise, falls back to
        // the old diameter-only proxy unchanged, so a plant nobody has measured yet behaves
        // exactly as it did before this existed.
        let reserveMm: Double
        let usedRealGeometry: Bool
        if let top = input.containerTopDiameterCm, let bottom = input.containerBottomDiameterCm,
           let height = input.containerHeightCm, top > 0, height > 0 {
            let volumeLiters = frustumVolumeLiters(topDiameterCm: top, bottomDiameterCm: bottom, heightCm: height)
            let awc = input.substrateAWC ?? Input.defaultAvailableWaterCapacity
            let capacityLiters = volumeLiters * awc
            let topRadiusM = (top / 2) / 100
            let surfaceAreaM2 = Double.pi * topRadiusM * topRadiusM
            reserveMm = surfaceAreaM2 > 0 ? capacityLiters / surfaceAreaM2 : reserveDepth(diameterCm: input.containerDiameterCm ?? Input.defaultContainerDiameterCm)
            usedRealGeometry = true
        } else {
            let diameter = input.containerDiameterCm ?? Input.defaultContainerDiameterCm
            reserveMm = reserveDepth(diameterCm: diameter)
            usedRealGeometry = false
        }

        // Rain, forecast or recorded, extends the cycle by directly offsetting loss.
        let rainOffsetMm = input.recentRainMm + upcomingRainMm(weather: input.weather)
        let sharedReserve = reserveMm + rainOffsetMm * 0.5 // rain only partially useful; runoff

        // Several plants sharing one container split the same reserve between them — the
        // whole pot's water doesn't belong to any single one of them.
        let plantCount = max(1, input.containerPlantCount ?? 1)
        let effectiveReserve = sharedReserve / Double(plantCount)

        let rawDays = effectiveReserve / dailyLossMm
        let clamped = min(maxCycleDays, max(minCycleDays, Int(rawDays.rounded())))

        return Output(
            cycleDays: clamped,
            et0MmPerDay: et0,
            dailyLossMmPerDay: dailyLossMm,
            exposureModifier: exposureModifier,
            materialModifier: materialModifier,
            reserveMm: reserveMm,
            rainOffsetMm: rainOffsetMm,
            effectiveReserveMm: effectiveReserve,
            rawDays: rawDays,
            usedRealGeometry: usedRealGeometry
        )
    }

    // MARK: - Evapotranspiration (FAO-56 Penman-Monteith)

    /// Full FAO-56 Penman-Monteith reference ET0, replacing an earlier Hargreaves estimate.
    /// Hargreaves only needs temperature, and is documented to overestimate ET0 in humid
    /// conditions specifically because it ignores humidity, wind and solar radiation — this
    /// uses all three, now that `WeatherSnapshot` already carries humidity, wind and cloud
    /// cover (previously read only into the AI's prompt context, never into this
    /// deterministic calculation). Reference: FAO Irrigation and Drainage Paper 56, ch. 2-4.
    private static func estimateET0(weather: WeatherContext?, latitude: Double?) -> Double {
        guard let weather else { return 2.5 } // Conservative default without weather data.

        let tMax = weather.current.tempMaxC ?? weather.current.tempC + 5
        let tMin = weather.current.tempMinC ?? weather.current.tempC - 5
        let tMean = (tMax + tMin) / 2

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 180
        let ra = extraterrestrialRadiation(latitude: latitude ?? 0, dayOfYear: dayOfYear)

        // Slope of the saturation vapor pressure curve (kPa/°C) at mean temperature.
        let delta = 4098 * saturationVaporPressure(tMean) / pow(tMean + 237.3, 2)

        // Psychrometric constant (kPa/°C), from assumed sea-level atmospheric pressure.
        let pressure = 101.3 * pow((293 - 0.0065 * assumedElevationM) / 293, 5.26)
        let gamma = 0.665e-3 * pressure

        // Mean saturation vapor pressure from Tmax/Tmin, and actual vapor pressure from mean
        // relative humidity — a simplification of FAO-56's RHmax/RHmin form, since a weather
        // snapshot gives one humidity reading, not separate day/night extremes.
        let es = (saturationVaporPressure(tMax) + saturationVaporPressure(tMin)) / 2
        let ea = es * Double(weather.current.humidity) / 100

        // Solar radiation from cloud cover (Angstrom-Prescott, using cloud cover as a stand
        // in for the sunshine-hours ratio n/N — the standard substitution when actual
        // sunshine duration isn't measured, which neither WeatherKit nor WeatherAPI give us).
        let sunshineFraction = max(0, min(1, 1 - Double(weather.current.cloudPct) / 100))
        let rs = (0.25 + 0.50 * sunshineFraction) * ra
        let rso = (0.75 + 2e-5 * assumedElevationM) * ra // clear-sky radiation

        let rns = (1 - 0.23) * rs // net shortwave radiation, albedo 0.23 for reference grass
        let tMaxK4 = pow(tMax + 273.16, 4)
        let tMinK4 = pow(tMin + 273.16, 4)
        let rsRatio = rso > 0 ? min(1, rs / rso) : 1
        let rnl = 4.903e-9 * (tMaxK4 + tMinK4) / 2 * (0.34 - 0.14 * ea.squareRoot()) * (1.35 * rsRatio - 0.35)
        let rn = max(0, rns - rnl) // net radiation; soil heat flux G ~= 0 for a daily step

        // Wind at 2m — neither weather source reports its sensor height, so this treats the
        // reported speed as already representative at 2m, the standard FAO-56 fallback when
        // the true measurement height is unknown.
        let u2 = weather.current.windKph / 3.6

        let numerator = 0.408 * delta * rn + gamma * (900 / (tMean + 273)) * u2 * (es - ea)
        let denominator = delta + gamma * (1 + 0.34 * u2)
        let et0 = numerator / denominator

        return max(0.5, et0)
    }

    /// Saturation vapor pressure (kPa) at a given temperature (°C) — FAO-56 eq. 11.
    private static func saturationVaporPressure(_ tempC: Double) -> Double {
        0.6108 * exp(17.27 * tempC / (tempC + 237.3))
    }

    /// Extraterrestrial radiation (MJ/m²/day) from latitude and day of year — FAO-56 eq.
    /// 21-25. Feeds both the net-radiation term above and, via `rso`, the clear-sky ratio.
    private static func extraterrestrialRadiation(latitude: Double, dayOfYear: Int) -> Double {
        let latRad = latitude * .pi / 180
        let dr = 1 + 0.033 * cos(2 * .pi / 365 * Double(dayOfYear))
        let delta = 0.409 * sin(2 * .pi / 365 * Double(dayOfYear) - 1.39)
        let ws = acos(max(-1, min(1, -tan(latRad) * tan(delta))))
        let ra = (24 * 60 / .pi) * 0.082 * dr
            * (ws * sin(latRad) * sin(delta) + cos(latRad) * cos(delta) * sin(ws))
        return max(0.1, ra)
    }

    // MARK: - Modifiers

    /// Matches the literal Spanish strings `AddPlantViewModel.locationOptions` actually
    /// stores in `Plant.sunRequirement`, plus the English forms for forward-compatibility
    /// if that ever changes. Was previously matching ONLY the English forms, so every plant
    /// added through the real add-flow (which stores "Interior luminoso" etc.) silently fell
    /// through to the 1.0 default — found while explaining an unexpectedly long cycle to the owner.
    private static func exposureFactor(sunRequirement: String?) -> Double {
        switch sunRequirement?.lowercased() {
        case "full sun", "exterior sol": 1.3
        case "partial shade", "exterior sombra": 1.0
        case "indirect light", "interior luminoso": 0.85
        case "low light", "interior sombrío", "interior sombrio": 0.6
        default: 1.0
        }
    }

    private static func materialFactor(containerMaterial: String?) -> Double {
        switch containerMaterial?.lowercased() {
        case "terracotta", "clay": 1.25 // porous, evaporates through the walls
        case "plastic": 0.9
        case "ceramic", "glazed": 1.0
        default: 1.0
        }
    }

    /// Depth-equivalent reserve (mm) as a function of pot diameter, used as a proxy for
    /// substrate depth (larger pots are typically proportionally deeper too).
    private static func reserveDepth(diameterCm: Double) -> Double {
        // Roughly linear: a 12cm pot holds shallow reserve, a 30cm pot holds much more.
        max(20, diameterCm * reserveDepthPerCm)
    }

    private static func upcomingRainMm(weather: WeatherContext?) -> Double {
        guard let weather else { return 0 }
        return weather.forecast.prefix(3).reduce(0) { $0 + $1.rainMm }
    }

    /// Volume of a frustum (a cone with the tip cut off) — the correct shape for a typical pot
    /// whose top and bottom diameters differ, per
    /// docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md section 1.1. Standard solid-geometry
    /// formula, not something specific to horticulture; the litre conversion (1 L = 1000 cm³)
    /// is what makes it usable directly against ml quantities elsewhere in the app.
    static func frustumVolumeLiters(topDiameterCm: Double, bottomDiameterCm: Double, heightCm: Double) -> Double {
        let topRadius = topDiameterCm / 2
        let bottomRadius = bottomDiameterCm / 2
        let volumeCm3 = (Double.pi * heightCm / 3) * (topRadius * topRadius + topRadius * bottomRadius + bottomRadius * bottomRadius)
        return volumeCm3 / 1000
    }
}
