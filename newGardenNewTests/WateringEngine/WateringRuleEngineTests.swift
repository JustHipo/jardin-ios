import Testing
@testable import newGardenNew

/// Tests for the deterministic water balance engine — the floor under the AI, not a
/// fallback for when it's missing. See docs/ANALISIS_IMPLEMENTACION.md section 3.
///
/// This is exactly the kind of thing the redesign argued for: a plain function with no
/// model, no network, testable with asserts. The old codebase could not test its watering
/// logic this way because the number came out of an LLM.
struct WateringRuleEngineTests {

    @Test("Cycle length is always within the sane clamp range")
    func staysWithinBounds() {
        let output = WateringRuleEngine.computeCycle(.init(
            containerDiameterCm: nil,
            containerMaterial: nil,
            sunRequirement: nil,
            cropCoefficient: 0.6,
            weather: nil,
            latitude: nil,
            recentRainMm: 0
        ))
        #expect(output.cycleDays >= WateringRuleEngine.minCycleDays)
        #expect(output.cycleDays <= WateringRuleEngine.maxCycleDays)
    }

    @Test("A succulent's low crop coefficient produces a longer cycle than a tropical plant's")
    func succulentWatersLessThanTropical() {
        let base = WateringRuleEngine.Input(
            containerDiameterCm: 18,
            containerMaterial: "plastic",
            sunRequirement: nil,
            cropCoefficient: FunctionalGroup.succulent.cropCoefficient,
            weather: nil,
            latitude: nil,
            recentRainMm: 0
        )
        let tropical = WateringRuleEngine.Input(
            containerDiameterCm: 18,
            containerMaterial: "plastic",
            sunRequirement: nil,
            cropCoefficient: FunctionalGroup.tropicalIndoor.cropCoefficient,
            weather: nil,
            latitude: nil,
            recentRainMm: 0
        )
        let succulentCycle = WateringRuleEngine.computeCycle(base).cycleDays
        let tropicalCycle = WateringRuleEngine.computeCycle(tropical).cycleDays
        #expect(succulentCycle > tropicalCycle)
    }

    @Test("A larger pot holds more reserve and stretches the cycle")
    func largerPotWatersLessOften() {
        let small = WateringRuleEngine.Input(
            containerDiameterCm: 10, containerMaterial: "plastic", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0
        )
        let large = WateringRuleEngine.Input(
            containerDiameterCm: 30, containerMaterial: "plastic", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0
        )

        let smallCycle = WateringRuleEngine.computeCycle(small).cycleDays
        let largeCycle = WateringRuleEngine.computeCycle(large).cycleDays
        #expect(largeCycle > smallCycle)
    }

    @Test("Terracotta evaporates faster than plastic, so the cycle shortens")
    func terracottaWatersMoreOftenThanPlastic() {
        let plastic = WateringRuleEngine.Input(
            containerDiameterCm: 18, containerMaterial: "plastic", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0
        )
        let terracotta = WateringRuleEngine.Input(
            containerDiameterCm: 18, containerMaterial: "terracotta", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0
        )

        let plasticCycle = WateringRuleEngine.computeCycle(plastic).cycleDays
        let terracottaCycle = WateringRuleEngine.computeCycle(terracotta).cycleDays
        #expect(terracottaCycle < plasticCycle)
    }

    @Test("Full sun dries the pot faster than low light")
    func fullSunWatersMoreOftenThanLowLight() {
        let lowLight = WateringRuleEngine.Input(
            containerDiameterCm: 18, containerMaterial: "plastic", sunRequirement: "low light",
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0
        )
        let fullSun = WateringRuleEngine.Input(
            containerDiameterCm: 18, containerMaterial: "plastic", sunRequirement: "full sun",
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0
        )

        let lowLightCycle = WateringRuleEngine.computeCycle(lowLight).cycleDays
        let fullSunCycle = WateringRuleEngine.computeCycle(fullSun).cycleDays
        #expect(fullSunCycle < lowLightCycle)
    }

    @Test("Recent rain extends the cycle, never shortens it")
    func recentRainExtendsCycle() {
        let dry = WateringRuleEngine.Input(
            containerDiameterCm: 18, containerMaterial: "plastic", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0
        )
        let rained = WateringRuleEngine.Input(
            containerDiameterCm: 18, containerMaterial: "plastic", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 40
        )

        let dryCycle = WateringRuleEngine.computeCycle(dry).cycleDays
        let rainedCycle = WateringRuleEngine.computeCycle(rained).cycleDays
        #expect(rainedCycle >= dryCycle)
    }

    @Test("The same input always produces the same output — no hidden randomness")
    func isDeterministic() {
        let input = WateringRuleEngine.Input(
            containerDiameterCm: 15, containerMaterial: "ceramic", sunRequirement: "partial shade",
            cropCoefficient: 0.8, weather: nil, latitude: -33.4, recentRainMm: 5
        )
        let first = WateringRuleEngine.computeCycle(input).cycleDays
        let second = WateringRuleEngine.computeCycle(input).cycleDays
        #expect(first == second)
    }

    // MARK: - Real geometry (docs/INVESTIGACION_ACADEMICA_RIEGO_MACETAS.md)

    @Test("A frustum volume matches the standard solid-geometry formula")
    func frustumVolumeMatchesFormula() {
        // A perfect cylinder (top == bottom) of 20cm diameter and 20cm height:
        // V = pi * r^2 * h = pi * 10^2 * 20 = 6283.19 cm^3 = 6.28319 L.
        let liters = WateringRuleEngine.frustumVolumeLiters(topDiameterCm: 20, bottomDiameterCm: 20, heightCm: 20)
        #expect(abs(liters - 6.283) < 0.01)
    }

    @Test("Real geometry is used when all three dimensions are present, and reflected in the output")
    func usesRealGeometryWhenAvailable() {
        let withGeometry = WateringRuleEngine.Input(
            containerDiameterCm: 20, containerMaterial: "plastic", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0,
            containerTopDiameterCm: 20, containerBottomDiameterCm: 15, containerHeightCm: 18,
            substrateAWC: 0.30
        )
        let output = WateringRuleEngine.computeCycle(withGeometry)
        #expect(output.usedRealGeometry)
    }

    @Test("Missing any one of the three geometry fields falls back to the diameter proxy")
    func fallsBackToProxyWhenGeometryIncomplete() {
        let missingHeight = WateringRuleEngine.Input(
            containerDiameterCm: 20, containerMaterial: "plastic", sunRequirement: nil,
            cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0,
            containerTopDiameterCm: 20, containerBottomDiameterCm: 15, containerHeightCm: nil
        )
        #expect(!WateringRuleEngine.computeCycle(missingHeight).usedRealGeometry)
    }

    @Test("A richer substrate (higher AWC) extends the cycle versus a poorer one, same geometry")
    func higherAWCExtendsCycle() {
        func input(awc: Double) -> WateringRuleEngine.Input {
            .init(
                containerDiameterCm: 20, containerMaterial: "plastic", sunRequirement: nil,
                cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0,
                containerTopDiameterCm: 20, containerBottomDiameterCm: 20, containerHeightCm: 20,
                substrateAWC: awc
            )
        }
        let poorSubstrate = WateringRuleEngine.computeCycle(input(awc: 0.10)).cycleDays // fresh pine bark
        let richSubstrate = WateringRuleEngine.computeCycle(input(awc: 0.30)).cycleDays // peat
        #expect(richSubstrate > poorSubstrate)
    }

    @Test("A taller pot with the same diameters holds more water and waters less often")
    func tallerPotWatersLessOften() {
        func input(heightCm: Double) -> WateringRuleEngine.Input {
            .init(
                containerDiameterCm: 20, containerMaterial: "plastic", sunRequirement: nil,
                cropCoefficient: 0.7, weather: nil, latitude: nil, recentRainMm: 0,
                containerTopDiameterCm: 20, containerBottomDiameterCm: 20, containerHeightCm: heightCm,
                substrateAWC: 0.30
            )
        }
        let shortPot = WateringRuleEngine.computeCycle(input(heightCm: 10)).cycleDays
        let tallPot = WateringRuleEngine.computeCycle(input(heightCm: 30)).cycleDays
        #expect(tallPot > shortPot)
    }
}
