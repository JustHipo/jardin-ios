import SwiftUI
import SwiftData

/// A simplified KPI dashboard: what the watering engine, the AI correction and the new
/// calibration/cross-check layers have actually been doing, categorized, sectioned by day and
/// filterable by category and by plant. Answers "¿cómo vamos a ver si mejoró?" from
/// docs/BASELINE_ALGORITMO_RIEGO.md — this is that "cómo".
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    if let viewModel {
                        summaryGrid(viewModel.summary)
                        filterBar(viewModel)
                        entryFeed(viewModel)
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.top, DS.Space.sm)
                .padding(.bottom, DS.Space.xxl)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .navigationTitle(String(localized: "tab.dashboard", defaultValue: "Registro"))
            .task {
                if viewModel == nil {
                    viewModel = DashboardViewModel(modelContext: modelContext)
                }
                viewModel?.load()
            }
            .onAppear { viewModel?.load() }
            .refreshable { viewModel?.load() }
        }
    }

    // MARK: - KPI summary

    private func summaryGrid(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.sm) {
            kpiTile(
                title: String(localized: "dashboard.kpi.analyses", defaultValue: "Análisis corridos"),
                value: "\(summary.totalAnalyses)",
                symbol: "chart.bar.doc.horizontal",
                tint: DS.Color.brand
            )
            kpiTile(
                title: String(localized: "dashboard.kpi.aiCorrections", defaultValue: "Con ajuste de IA"),
                value: "\(summary.analysesWithAICorrection)",
                symbol: "sparkles",
                tint: DS.Color.aiAccent
            )
            kpiTile(
                title: String(localized: "dashboard.kpi.calibrating", defaultValue: "Plantas calibrándose"),
                value: "\(summary.plantsWithActiveCalibration)",
                symbol: "slider.horizontal.3",
                tint: DS.Color.statusOK
            )
            kpiTile(
                title: String(localized: "dashboard.kpi.et0", defaultValue: "ET0 vs Open-Meteo"),
                value: summary.averageEt0DeltaPct.map { String(format: "%+.0f%%", $0) }
                    ?? String(localized: "dashboard.kpi.noData", defaultValue: "Sin datos"),
                symbol: "arrow.left.arrow.right",
                tint: DS.Color.statusSoon,
                footnote: summary.et0SampleCount > 0
                    ? String(localized: "dashboard.kpi.et0Footnote", defaultValue: "\(summary.et0SampleCount) comparaciones")
                    : nil
            )
        }
    }

    private func kpiTile(title: String, value: String, symbol: String, tint: Color, footnote: String? = nil) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text(value).font(.title2.bold()).monospacedDigit()
                Text(title).font(DS.Text.caption).foregroundStyle(.secondary)
                if let footnote {
                    Text(footnote).font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Filters

    private func filterBar(_ viewModel: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.xs) {
                    categoryChip(nil, label: String(localized: "dashboard.filter.all", defaultValue: "Todo"), viewModel: viewModel)
                    ForEach(DashboardCategory.allCases) { category in
                        categoryChip(category, label: category.label, viewModel: viewModel)
                    }
                }
            }

            if !viewModel.plantNames.isEmpty {
                Menu {
                    Button(String(localized: "dashboard.filter.allPlants", defaultValue: "Todas las plantas")) {
                        viewModel.selectedPlantName = nil
                    }
                    ForEach(viewModel.plantNames, id: \.self) { name in
                        Button(name) { viewModel.selectedPlantName = name }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf")
                        Text(viewModel.selectedPlantName ?? String(localized: "dashboard.filter.allPlants", defaultValue: "Todas las plantas"))
                        Image(systemName: "chevron.down").font(.system(size: 10))
                    }
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func categoryChip(_ category: DashboardCategory?, label: String, viewModel: DashboardViewModel) -> some View {
        let isSelected = viewModel.selectedCategory == category
        let tint = category?.tint ?? DS.Color.brand
        return Button {
            viewModel.selectedCategory = category
        } label: {
            HStack(spacing: 4) {
                if let category {
                    Image(systemName: category.symbolName).font(.system(size: 10, weight: .semibold))
                }
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, 6)
            .background(isSelected ? tint : DS.Color.surfaceSunken, in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
            .overlay(Capsule().strokeBorder(DS.Color.hairline, lineWidth: isSelected ? 0 : 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feed, sectioned by day

    @ViewBuilder
    private func entryFeed(_ viewModel: DashboardViewModel) -> some View {
        let entries = viewModel.filteredEntries
        if entries.isEmpty {
            emptyState
        } else {
            let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.occurredAt) }
            let days = grouped.keys.sorted(by: >)
            VStack(alignment: .leading, spacing: DS.Space.md) {
                ForEach(days, id: \.self) { day in
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(day.formatted(date: .abbreviated, time: .omitted))
                            .font(DS.Text.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(grouped[day] ?? []) { entry in
                            entryRow(entry)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        DSCard {
            VStack(spacing: DS.Space.xs) {
                Image(systemName: "tray").font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
                Text(String(localized: "dashboard.empty", defaultValue: "Todavía no hay nada que mostrar con este filtro."))
                    .font(DS.Text.detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.sm)
        }
    }

    private func entryRow(_ entry: DashboardEntry) -> some View {
        DSCard {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: entry.category.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(entry.category.tint)
                    .frame(width: 20, alignment: .center)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title).font(DS.Text.cardTitle)
                        Spacer()
                        Text(entry.occurredAt.formatted(date: .omitted, time: .shortened))
                            .font(DS.Text.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.detail).font(DS.Text.detail).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private extension DashboardCategory {
    var tint: Color {
        switch self {
        case .calibration: DS.Color.brand
        case .analysis: DS.Color.aiAccent
        case .engine: DS.Color.statusSoon
        case .et0CrossCheck: DS.Color.statusOK
        }
    }
}
