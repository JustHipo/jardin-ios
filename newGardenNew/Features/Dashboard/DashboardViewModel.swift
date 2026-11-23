import Foundation
import SwiftData
import Observation

/// The four kinds of entry the dashboard shows, each backed by a different model that already
/// existed for its own reason (audit trail, per-analysis record) or was added specifically so
/// this dashboard would have something durable to read (calibration history, ET0 cross-check
/// history) instead of only a running scalar or an `os.Logger` line that scrolls away.
enum DashboardCategory: String, CaseIterable, Identifiable, Sendable {
    case calibration
    case analysis
    case engine
    case et0CrossCheck

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calibration: String(localized: "dashboard.category.calibration", defaultValue: "Calibración")
        case .analysis: String(localized: "dashboard.category.analysis", defaultValue: "Análisis de riego")
        case .engine: String(localized: "dashboard.category.engine", defaultValue: "Motor")
        case .et0CrossCheck: String(localized: "dashboard.category.et0", defaultValue: "ET0 vs Open-Meteo")
        }
    }

    var symbolName: String {
        switch self {
        case .calibration: "slider.horizontal.3"
        case .analysis: "drop.degreesign"
        case .engine: "cpu"
        case .et0CrossCheck: "arrow.left.arrow.right"
        }
    }
}

/// One row in the feed, normalized from whichever underlying model produced it so the view
/// can sort, group and filter all four kinds together instead of showing four separate lists.
struct DashboardEntry: Identifiable {
    let id: UUID
    let occurredAt: Date
    let category: DashboardCategory
    let plantName: String?
    let title: String
    let detail: String
}

/// The KPI numbers at the top of the dashboard: a handful of counts and one average, not a
/// full analytics suite — simplified on purpose, per what was asked for.
struct DashboardSummary {
    let totalAnalyses: Int
    let analysesWithAICorrection: Int
    let et0SampleCount: Int
    let averageEt0DeltaPct: Double?
    let plantsWithActiveCalibration: Int

    static let empty = DashboardSummary(
        totalAnalyses: 0, analysesWithAICorrection: 0, et0SampleCount: 0,
        averageEt0DeltaPct: nil, plantsWithActiveCalibration: 0
    )
}

/// A simple KPI dashboard over data this app was already collecting for auditability
/// (`AIAnalysis`, `AIAuditEntry`) plus two new durable histories added specifically so this
/// screen would have something to show (`WateringCalibrationEvent`, `ET0CrossCheckEntry`) —
/// see those models' doc comments for why a running scalar and `os.Logger` weren't enough.
/// See docs/BASELINE_ALGORITMO_RIEGO.md for the first real numbers this surfaced.
@MainActor
@Observable
final class DashboardViewModel {
    private let modelContext: ModelContext

    private(set) var entries: [DashboardEntry] = []
    private(set) var plantNames: [String] = []
    private(set) var summary: DashboardSummary = .empty

    var selectedCategory: DashboardCategory?
    var selectedPlantName: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var filteredEntries: [DashboardEntry] {
        entries.filter { entry in
            (selectedCategory == nil || entry.category == selectedCategory)
                && (selectedPlantName == nil || entry.plantName == selectedPlantName)
        }
    }

    func load() {
        let analyses = fetch(FetchDescriptor<AIAnalysis>(sortBy: [SortDescriptor(\.analyzedAt, order: .reverse)]))
        let audits = fetch(FetchDescriptor<AIAuditEntry>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]))
        let calibrations = fetch(FetchDescriptor<WateringCalibrationEvent>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]))
        let crossChecks = fetch(FetchDescriptor<ET0CrossCheckEntry>(sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]))
        let plants = fetch(FetchDescriptor<Plant>())

        var mapped: [DashboardEntry] = []
        mapped += analyses.map(Self.entry)
        mapped += audits.map(Self.entry)
        mapped += calibrations.map(Self.entry)
        mapped += crossChecks.map(Self.entry)

        entries = mapped.sorted { $0.occurredAt > $1.occurredAt }
        plantNames = Array(Set(mapped.compactMap(\.plantName))).sorted()
        summary = DashboardSummary(
            totalAnalyses: analyses.count,
            analysesWithAICorrection: analyses.filter { $0.aiCorrectionDays != nil }.count,
            et0SampleCount: crossChecks.count,
            averageEt0DeltaPct: crossChecks.isEmpty ? nil : crossChecks.map(\.deltaPct).reduce(0, +) / Double(crossChecks.count),
            plantsWithActiveCalibration: plants.filter { abs($0.waterCalibrationMultiplier - WateringCalibration.neutral) > 0.01 }.count
        )
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Mapping each model into a normalized entry

    private static func entry(_ analysis: AIAnalysis) -> DashboardEntry {
        var parts: [String] = []
        if let baseline = analysis.ruleBaselineDays {
            parts.append(String(localized: "dashboard.analysis.rules", defaultValue: "Reglas: cada \(baseline) días"))
        }
        if let correction = analysis.aiCorrectionDays {
            let sign = correction > 0 ? "+" : ""
            parts.append(String(localized: "dashboard.analysis.aiCorrection", defaultValue: "IA: \(sign)\(correction) días"))
        }
        parts.append(String(localized: "dashboard.analysis.final", defaultValue: "Ajuste final: \(analysis.adjustDays) días"))
        return DashboardEntry(
            id: analysis.id, occurredAt: analysis.analyzedAt, category: .analysis,
            plantName: analysis.plant?.name,
            title: analysis.plant?.name ?? String(localized: "dashboard.unknownPlant", defaultValue: "Planta"),
            detail: parts.joined(separator: " · ")
        )
    }

    private static func entry(_ audit: AIAuditEntry) -> DashboardEntry {
        let statusWord = audit.succeeded
            ? String(localized: "dashboard.engine.answered", defaultValue: "Respondió")
            : String(localized: "dashboard.engine.failed", defaultValue: "Falló")
        var detail = "\(statusWord): \(engineLabel(audit.engine))"
        if let reason = audit.fallbackReason {
            detail += " (\(reason))"
        }
        return DashboardEntry(
            id: audit.id, occurredAt: audit.occurredAt, category: .engine,
            plantName: audit.plant?.name,
            title: taskLabel(audit.task),
            detail: detail
        )
    }

    private static func entry(_ event: WateringCalibrationEvent) -> DashboardEntry {
        let from = String(format: "%.2f", event.previousMultiplier)
        let to = String(format: "%.2f", event.updatedMultiplier)
        var detail = String(
            localized: "dashboard.calibration.detail",
            defaultValue: "Multiplicador \(from) → \(to) (regaste a los \(event.actualIntervalDays)d, se esperaban \(event.predictedCycleDays)d)"
        )
        if let appliedMl = event.appliedMl {
            let fillSuffix = event.fillFraction.map { " (\(String(format: "%.0f%%", $0 * 100)) de la maceta)" } ?? ""
            detail += " · " + String(
                localized: "dashboard.calibration.appliedMl",
                defaultValue: "\(Int(appliedMl)) ml aplicados\(fillSuffix)"
            )
        }
        return DashboardEntry(
            id: event.id, occurredAt: event.occurredAt, category: .calibration,
            plantName: event.plant?.name,
            title: event.plant?.name ?? String(localized: "dashboard.unknownPlant", defaultValue: "Planta"),
            detail: detail
        )
    }

    private static func entry(_ crossCheck: ET0CrossCheckEntry) -> DashboardEntry {
        let own = String(format: "%.2f", crossCheck.ownEt0MmPerDay)
        let reference = String(format: "%.2f", crossCheck.referenceEt0MmPerDay)
        let sign = crossCheck.deltaPct >= 0 ? "+" : ""
        let delta = "\(sign)\(String(format: "%.0f", crossCheck.deltaPct))%"
        return DashboardEntry(
            id: crossCheck.id, occurredAt: crossCheck.occurredAt, category: .et0CrossCheck,
            plantName: crossCheck.plant?.name,
            title: crossCheck.plant?.name ?? String(localized: "dashboard.unknownPlant", defaultValue: "Planta"),
            detail: String(
                localized: "dashboard.et0.detail",
                defaultValue: "Propio \(own) vs Open-Meteo \(reference) mm/día (\(delta))"
            )
        )
    }

    private static func engineLabel(_ engine: AIEngineKind) -> String {
        switch engine {
        case .ruleEngine: String(localized: "dashboard.engineLabel.rules", defaultValue: "Motor de reglas")
        case .onDeviceFoundationModels: String(localized: "dashboard.engineLabel.onDevice", defaultValue: "IA en el dispositivo")
        case .privateCloudCompute: String(localized: "dashboard.engineLabel.pcc", defaultValue: "Nube privada de Apple")
        case .userProvidedKey: String(localized: "dashboard.engineLabel.userKey", defaultValue: "Tu clave propia")
        case .plantNet: "PlantNet"
        }
    }

    private static func taskLabel(_ task: AITaskKind) -> String {
        switch task {
        case .wateringAdjustment: String(localized: "dashboard.taskLabel.watering", defaultValue: "Ajuste de riego")
        case .speciesIdentification: String(localized: "dashboard.taskLabel.species", defaultValue: "Identificación de especie")
        case .healthDiagnosis: String(localized: "dashboard.taskLabel.health", defaultValue: "Diagnóstico de salud")
        case .chat: String(localized: "dashboard.taskLabel.chat", defaultValue: "Chat")
        }
    }
}
