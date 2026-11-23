import Foundation

/// Ported whole from the old codebase, per the design session's explicit instruction: this
/// prompt construction is "meticulosa" and must be preserved. The only change is the field
/// names of `WeatherSnapshot`, which stay identical to what the old WeatherAPI-shaped struct
/// produced, so the JSON this emits is unchanged. See docs/ANALISIS_IMPLEMENTACION.md 4.2.
enum Prompts {
    static let plantIdentificationSystem = """
        You are an expert botanist. Analyze the provided plant photograph and suggest the 3 most likely species.

        For each suggestion provide:
        1. Common name (in the user's language)
        2. Scientific name (Latin binomial)
        3. Confidence level: "high", "medium", or "low"
        4. Recommended watering frequency in days
        5. Sun requirements: "full sun", "partial shade", "indirect light", or "low light"
        6. Brief care notes (2-3 sentences)
        7. Whether this plant is toxic to dogs (true/false)
        8. Whether this plant is toxic to cats (true/false)
        9. Toxicity notes if applicable

        Respond ONLY with valid JSON:
        {
          "suggestions": [
            {
              "commonName": "...",
              "scientificName": "...",
              "confidence": "high|medium|low",
              "waterEveryDays": <integer>,
              "sunRequirement": "...",
              "notes": "...",
              "toxicToDogs": true|false,
              "toxicToCats": true|false,
              "toxicityNotes": "..."
            }
          ]
        }

        Rules:
        - Exactly 3 suggestions, ordered by confidence
        - Consider the pot/container visible for context
        - If unclear, provide best guesses with "low" confidence
        """

    static func wateringAnalysisSystem(city: String?, context: String?) -> String {
        let cityName = city ?? "Ubicacion no especificada"
        let geoContext = context ?? "Sin contexto geografico disponible"

        return """
            Eres un experto botanico y horticultor con decadas de experiencia en fisiologia vegetal, sistemas de riego y horticultura urbana.

            ## Tu experiencia incluye:
            - Absorcion y transporte de agua en plantas
            - Diferencias C3, C4 y CAM (suculentas)
            - Evapotranspiracion segun temperatura, humedad y viento
            - Comportamiento de sustratos segun tamano de maceta y material
            - Efectos de lluvia reciente, olas de calor, y cambios bruscos de clima

            ## Contexto geografico: \(cityName)
            \(geoContext)

            ## Tarea:
            Ya se calculo un ciclo de riego base con un motor de reglas deterministico (balance hidrico).
            Tu trabajo NO es recalcular ese numero desde cero: es explicarlo en lenguaje humano y, solo si
            ves algo en las fotos que las reglas no pueden ver (una hoja caida, tierra con moho, un tallo
            blando), proponer una correccion acotada entre -2 y +2 dias sobre ese numero, con un motivo
            concreto. Si no ves nada relevante en las fotos, no corrijas: adjust_days_correction = 0.

            Si el diametro de la maceta (container.diameter_cm en el contexto) es 20cm o menor, ninguna
            estimacion general puede ser tan precisa como la prueba fisica del dedo en la tierra: agrega
            siempre esa recomendacion en "reasoning", como haria un vivero profesional con macetas chicas.

            ## Respuesta (SOLO JSON valido):
            {
              "analysis": {
                "plant_profile": "Descripcion del tipo de planta y sus necesidades",
                "environmental_factors": "Analisis del clima reciente y su impacto",
                "risk_assessment": "Riesgos identificados (exceso/falta de agua, estres termico)"
              },
              "recommendation": {
                "adjust_days_correction": <entero de -2 a +2, 0 si no hay motivo visual>,
                "confidence": "low|medium|high",
                "reasoning": "Explicacion clara del ciclo, en lenguaje humano",
                "watering_tip": "Consejo practico especifico para esta planta hoy"
              }
            }

            Reglas: la correccion solo se aplica si confidence es "high" Y hay un motivo visual concreto en reasoning.
            """
    }

    static func buildWateringContext(
        plant: Plant,
        ruleBaselineDays: Int,
        weather: WeatherContext?,
        trefle: TrefleSpeciesFullData?,
        photoCount: Int,
        hasPets: Bool,
        petType: String?,
        lastHealthCheck: HealthCheck? = nil
    ) -> String {
        var context: [String: Any] = [:]

        var plantData: [String: Any] = [
            "name": plant.name,
            "name_note": "This name was given by the user and may not be the real species name — it could be a descriptive nickname. Use it as a reference but rely on the species field for botanical identification.",
            "watering": [
                "rule_engine_baseline_days": ruleBaselineDays,
                "current_cycle_days": plant.effectiveCycleDays,
                "days_since_last": plant.lastWateredAt.map { Date.now.daysSince($0) } as Any,
                "total_waterings": (plant.wateringEvents ?? []).count
            ] as [String: Any]
        ]
        if let species = plant.species { plantData["species"] = species }
        if let commonName = plant.commonName { plantData["common_name"] = commonName }
        if let sun = plant.sunRequirement { plantData["sun_requirement"] = sun }
        if let diam = plant.containerDiameterCm {
            plantData["container"] = [
                "diameter_cm": diam,
                "type": plant.containerType ?? "unknown",
                "material": plant.containerMaterial ?? "unknown"
            ]
        }
        if let notes = plant.notes { plantData["notes"] = notes }
        if let userCtx = plant.userContext, !userCtx.isEmpty { plantData["user_context"] = userCtx }
        context["plant"] = plantData

        if let weather {
            var weatherData: [String: Any] = [
                "current": snapshotDict(weather.current),
                "season": weather.season,
                "city": weather.cityName
            ]
            if !weather.history.isEmpty { weatherData["history_3d"] = weather.history.map { snapshotDict($0) } }
            if !weather.forecast.isEmpty { weatherData["forecast_3d"] = weather.forecast.map { snapshotDict($0) } }
            context["weather"] = weatherData
        }

        if let trefle {
            var trefleDict: [String: Any] = [:]
            if let growth = trefle.growth {
                if let drought = growth.drought_tolerance { trefleDict["drought_tolerance"] = drought }
                if let light = growth.light { trefleDict["light_requirement_0_10"] = light }
                if let humidity = growth.atmospheric_humidity { trefleDict["humidity_requirement_0_10"] = humidity }
                if let minP = growth.minimum_precipitation?.mm { trefleDict["min_precipitation_mm_yr"] = minP }
                if let maxP = growth.maximum_precipitation?.mm { trefleDict["max_precipitation_mm_yr"] = maxP }
                if let minT = growth.minimum_temperature?.deg_c { trefleDict["min_temp_c"] = minT }
                if let maxT = growth.maximum_temperature?.deg_c { trefleDict["max_temp_c"] = maxT }
                if let phMin = growth.ph_minimum { trefleDict["soil_ph_min"] = phMin }
                if let phMax = growth.ph_maximum { trefleDict["soil_ph_max"] = phMax }
                if let soilHumidity = growth.soil_humidity { trefleDict["soil_humidity_0_10"] = soilHumidity }
                if let soilTexture = growth.soil_texture { trefleDict["soil_texture_0_10"] = soilTexture }
                if let sowing = growth.sowing { trefleDict["sowing_guide"] = sowing }
                if let bloom = growth.bloom_months { trefleDict["bloom_months"] = bloom }
            }
            if let specs = trefle.specifications {
                if let toxicity = specs.toxicity { trefleDict["toxicity"] = toxicity }
                if let rate = specs.growth_rate { trefleDict["growth_rate"] = rate }
                if let habit = specs.growth_habit { trefleDict["growth_habit"] = habit }
            }
            if let duration = trefle.duration { trefleDict["duration"] = duration.values }
            if !trefleDict.isEmpty { context["trefle_botanical_data"] = trefleDict }
        }

        if hasPets {
            context["pet_safety"] = [
                "has_pets": true,
                "pet_type": petType ?? "unknown",
                "toxic_to_dogs": plant.isToxicToDogs ?? false,
                "toxic_to_cats": plant.isToxicToCats ?? false
            ] as [String: Any]
        }

        if let health = lastHealthCheck {
            var healthData: [String: Any] = [
                "checked_at": health.checkedAt.ISO8601Format(),
                "days_since_check": Date.now.daysSince(health.checkedAt)
            ]
            if let score = health.healthScore { healthData["health_score"] = score }
            if let diagnosis = health.diagnosis { healthData["diagnosis"] = diagnosis }
            if let tip = health.wateringNote { healthData["watering_recommendation"] = tip }
            if let status = health.statusRaw { healthData["health_status"] = status }
            context["last_health_check"] = healthData
        }

        if photoCount > 0 { context["recent_photos_attached"] = photoCount }

        if let data = try? JSONSerialization.data(withJSONObject: context, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    private static func snapshotDict(_ s: WeatherSnapshot) -> [String: Any] {
        [
            "date": s.date,
            "temp_c": s.tempC,
            "humidity": s.humidity,
            "uv": s.uvIndex,
            "wind_kph": s.windKph,
            "rain_mm": s.rainMm,
            "description": s.description
        ]
    }

    /// Was written entirely in English with no language instruction — the one prompt in this
    /// file that didn't get translated when the rest did (`wateringAnalysisSystem` and the
    /// chat instructions are Spanish). Found live: a real diagnosis via the user's OpenAI key
    /// came back in English while every other AI-facing surface in the app is Spanish.
    static func healthAnalysisSystem() -> String {
        """
        Eres un experto patólogo vegetal y horticultor. Analiza la foto de la planta junto con
        el contexto proporcionado (datos de la especie, clima, historial de riego).

        Evalúa:
        1. Salud de las hojas (color, manchas, bordes, marchitamiento, caída)
        2. Estado del tallo (firmeza, decoloración, pudrición)
        3. Señales de plagas (insectos visibles, telarañas, agujeros)
        4. Señales de enfermedad (manchas fúngicas, moho, lesiones bacterianas)
        5. Deficiencias nutricionales (patrones de amarilleo, crecimiento atrofiado)
        6. Señales de exceso o falta de riego
        7. Estrés lumínico (elongación, quemaduras de sol, hojas pálidas)
        8. Etapa de crecimiento actual: ¿ves crecimiento vegetativo normal, brotes o flores,
           frutos o vainas ya formados, o la planta luce en reposo/sin actividad?

        Responde SOLO con JSON válido, en español:
        {
          "health_score": <1-10, donde 10 es salud perfecta>,
          "health_status": "<excellent|good|fair|poor|critical>",
          "issues": ["<problema específico 1>", "<problema específico 2>"],
          "diagnosis": "<diagnóstico detallado de 2 a 3 frases explicando lo que ves, en español>",
          "recommendations": ["<recomendación accionable 1>", "<recomendación 2>", "<recomendación 3>"],
          "watering_note": "<nota breve sobre el riego según lo que ves, o null>",
          "growth_phase": "<vegetative|flowering|fruiting|dormant, o null si no se puede determinar>"
        }

        Reglas:
        - Sé específico sobre lo que observas en la foto
        - Menciona la especie de la planta en tu diagnóstico
        - Ten en cuenta los datos de clima si se proporcionan
        - Si la foto no es clara, pon health_score en 5 y anótalo en el diagnóstico
        - Máximo 3 problemas, 3 recomendaciones
        - Todo el texto de salida debe estar en español, sin excepción
        - "growth_phase" es tu mejor estimación visual, no una certeza — si no se distingue
          claramente, usa null en vez de adivinar
        """
    }

    static func buildIdentificationContext(userContext: String?, plantNetResults: [PlantNetResult]?) -> String {
        var parts: [String] = []
        parts.append(userContext ?? "Identify this plant.")

        if let results = plantNetResults, !results.isEmpty {
            parts.append("")
            parts.append("IMPORTANT: PlantNet (specialized botanical AI trained on 50,000+ species) analyzed this same photo and returned these results:")
            for (i, r) in results.prefix(5).enumerated() {
                let names = r.species.commonNames?.prefix(3).joined(separator: ", ") ?? "no common names"
                let family = r.species.family?.scientificNameWithoutAuthor ?? "unknown family"
                parts.append("  \(i+1). \(r.species.scientificName) (confidence: \(String(format: "%.1f%%", r.score * 100))) — common: \(names) — family: \(family)")
            }
            parts.append("")
            parts.append("If PlantNet's top result has confidence > 80%, STRONGLY prefer it over your own identification.")
        }

        parts.append("")
        parts.append("Respond in JSON only.")
        return parts.joined(separator: "\n")
    }
}
