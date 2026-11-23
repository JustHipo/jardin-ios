import Testing
import Foundation
@testable import newGardenNew

/// Tests for `Plant`'s derived watering state. This logic used to encode state as color
/// only (finding A4 of the audit); these tests exercise the underlying computation that
/// now backs color + shape + text together.
struct PlantWateringStatusTests {

    @Test("A plant never watered is 'neverWatered', not 'ok'")
    func neverWateredIsItsOwnState() {
        let plant = Plant(name: "Test")
        #expect(plant.wateringStatus == .neverWatered)
        #expect(plant.wateringProgress == nil)
    }

    @Test("Just watered, within the cycle, is 'ok'")
    func justWateredIsOK() {
        let plant = Plant(name: "Test", waterEveryDays: 7)
        plant.wateringEvents = [WateringEvent(wateredAt: .now)]
        #expect(plant.wateringStatus == .ok)
    }

    @Test("Past the cycle length is 'overdue'")
    func pastCycleIsOverdue() {
        let plant = Plant(name: "Test", waterEveryDays: 5)
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: .now)!
        plant.wateringEvents = [WateringEvent(wateredAt: eightDaysAgo)]
        #expect(plant.wateringStatus == .overdue)
    }

    @Test("An AI adjustment overrides the base cycle for status purposes")
    func adjustedCycleGovernsStatus() {
        let plant = Plant(name: "Test", waterEveryDays: 5)
        plant.waterEveryDaysAdjusted = 10
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        plant.wateringEvents = [WateringEvent(wateredAt: sevenDaysAgo)]
        // 7 days into a 10-day adjusted cycle: not yet overdue against the adjustment,
        // even though it WOULD be overdue against the original 5-day base cycle.
        #expect(plant.effectiveCycleDays == 10)
        #expect(plant.wateringStatus != .overdue)
    }
}

/// Tests for `PetSafetyVerdict`. The old app derived pet safety from an untyped
/// `UserDefaults` string key; a typo silently rendered every plant as safe. This type makes
/// "unknown" impossible to collapse into "safe" by accident.
struct PetSafetyVerdictTests {

    @Test("Unknown toxicity is its own case, never coerced to safe")
    func unknownIsNotSafe() {
        let verdict = PetSafetyVerdict(isToxic: nil, notes: nil)
        #expect(verdict != .safe)
        #expect(!verdict.isToxic)
        if case .unknown = verdict {} else { Issue.record("Expected .unknown") }
    }

    @Test("Explicit false is safe")
    func explicitFalseIsSafe() {
        let verdict = PetSafetyVerdict(isToxic: false, notes: nil)
        #expect(verdict == .safe)
    }

    @Test("Explicit true is toxic, with notes carried through")
    func explicitTrueIsToxicWithNotes() {
        let verdict = PetSafetyVerdict(isToxic: true, notes: "Oxalato de calcio")
        #expect(verdict.isToxic)
        if case .toxic(let notes) = verdict {
            #expect(notes == "Oxalato de calcio")
        } else {
            Issue.record("Expected .toxic")
        }
    }
}
