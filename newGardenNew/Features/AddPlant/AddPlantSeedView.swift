import SwiftUI

/// M08: sowing from seed creates a staged plan instead of a fixed cycle (P13). This is the
/// screen `mygarden-f9` flagged as needing the most design discussion before writing it —
/// the design session ended before that conversation happened, so the specifics below
/// (methods offered, default stage table) are MY reversible defaults, not confirmed design.
/// Flag these in the M08 validation checkpoint.
struct AddPlantSeedView: View {
    @Bindable var viewModel: AddPlantViewModel
    var onFinished: () -> Void

    private let methods: [(String, String)] = [
        (String(localized: "addPlant.seed.methodTray", defaultValue: "Semillero"), "square.grid.3x3.fill"),
        (String(localized: "addPlant.seed.methodPot", defaultValue: "Maceta"), "circle.grid.2x2"),
        (String(localized: "addPlant.seed.methodGround", defaultValue: "Directo a tierra"), "mountain.2.fill"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header
                seedField
                methodField
                dateField
                plan
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 100)
        }
        .background(DS.Color.surfaceSunken)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            DSPrimaryButton(title: String(localized: "addPlant.seed.save", defaultValue: "Crear plan de siembra"), systemImage: "checkmark") {
                viewModel.saveSeed()
                onFinished()
            }
            .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
            .background(.bar)
        }
        .navigationTitle(String(localized: "addPlant.seed.title", defaultValue: "Sembrar"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        DSCard(tint: DS.Color.brandSoft) {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: "circle.grid.cross.fill").font(.title3).foregroundStyle(DS.Color.brand)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(String(localized: "addPlant.seed.headerTitle", defaultValue: "Una semilla no se riega como una planta")).font(DS.Text.cardTitle)
                    Text(String(localized: "addPlant.seed.headerDetail", defaultValue: "La app va a cambiar el riego sola según la etapa.")).font(DS.Text.detail).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, DS.Space.xs)
    }

    private var seedField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(String(localized: "addPlant.seed.whatSeed", defaultValue: "¿Qué sembraste?")).font(DS.Text.sectionTitle)
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(String(localized: "addPlant.seed.searchPlaceholder", defaultValue: "Busca la semilla"), text: $viewModel.seedName)
                    .textFieldStyle(.plain).font(DS.Text.body)
            }
            .padding(DS.Space.sm)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(DS.Color.hairline, lineWidth: 0.5))
        }
    }

    private var methodField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(String(localized: "addPlant.seed.where", defaultValue: "¿Dónde?")).font(DS.Text.sectionTitle)
            HStack(spacing: DS.Space.xs) {
                ForEach(Array(methods.enumerated()), id: \.offset) { index, item in
                    let isSelected = viewModel.sowingMethod == index
                    Button {
                        withAnimation(DS.Motion.quick) { viewModel.sowingMethod = index }
                    } label: {
                        VStack(spacing: DS.Space.xs) {
                            Image(systemName: item.1).font(.title3)
                            Text(item.0).font(DS.Text.caption.weight(.medium)).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76)
                        .foregroundStyle(isSelected ? DS.Color.brand : .primary)
                        .background(isSelected ? DS.Color.brandSoft : DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(isSelected ? DS.Color.brand : DS.Color.hairline, lineWidth: isSelected ? 2 : 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(String(localized: "addPlant.seed.when", defaultValue: "¿Cuándo?")).font(DS.Text.sectionTitle)
            DatePicker(String(localized: "addPlant.seed.sownDate", defaultValue: "Fecha de siembra"), selection: $viewModel.sownDate, displayedComponents: .date)
                .font(DS.Text.body).padding(DS.Space.sm)
                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(DS.Color.hairline, lineWidth: 0.5))
        }
    }

    private var plan: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            DSSectionHeader(title: String(localized: "addPlant.seed.plan", defaultValue: "Plan de riego por etapa"))
            DSCard {
                VStack(spacing: 0) {
                    ForEach(Array(GrowthStage.allCases.enumerated()), id: \.offset) { index, stage in
                        stageRow(stage)
                        if index < GrowthStage.allCases.count - 1 { connector }
                    }
                }
            }
        }
    }

    private func stageRow(_ stage: GrowthStage) -> some View {
        let isCurrent = stage == .sowing
        return HStack(alignment: .top, spacing: DS.Space.sm) {
            Circle().fill(isCurrent ? DS.Color.brand : DS.Color.hairline).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.label).font(DS.Text.body.weight(isCurrent ? .semibold : .regular))
                Text(stageIntervalDescription(stage)).font(DS.Text.caption).foregroundStyle(.secondary)
                Text(stageDayRangeDescription(stage)).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func stageIntervalDescription(_ stage: GrowthStage) -> String {
        switch stage {
        case .sowing: String(localized: "growthStage.sowing.detail", defaultValue: "Sustrato húmedo constante, sin encharcar")
        case .germination: String(localized: "growthStage.germination.detail", defaultValue: "Riego por pulverización, 2 veces al día")
        case .seedling: String(localized: "growthStage.seedling.detail", defaultValue: "Riego cada 2 días, primera luz directa suave")
        case .transplanted: String(localized: "growthStage.transplanted.detail", defaultValue: "Maceta definitiva, riego cada 3 días")
        }
    }

    private func stageDayRangeDescription(_ stage: GrowthStage) -> String {
        let range = stage.typicalDayRange
        return range.upperBound == 9999
            ? "Día \(range.lowerBound) en adelante"
            : "Días \(range.lowerBound) a \(range.upperBound)"
    }

    private var connector: some View {
        HStack(spacing: DS.Space.sm) {
            Rectangle().fill(DS.Color.hairline).frame(width: 2, height: 18).padding(.leading, 12)
            Spacer()
        }
    }
}
