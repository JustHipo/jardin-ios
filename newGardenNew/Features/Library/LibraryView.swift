import SwiftUI
import SwiftData
import os

/// M02, wired to real data.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LibraryViewModel?
    @State private var showAddPlant = false
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: DS.Space.sm)]

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "tab.plants", defaultValue: "Plantas"))
            .navigationDestination(for: UUID.self) { plantId in PlantDetailView(plantId: plantId) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddPlant = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(String(localized: "today.addPlant", defaultValue: "Añadir planta"))
                }
            }
            .sheet(isPresented: $showAddPlant, onDismiss: {
                // Same fix as TodayView: `.onAppear` never fires here, the view was only
                // covered by the sheet, not replaced.
                AppLog.checkpoint.notice("Library: add-plant sheet dismissed")
                viewModel?.load()
            }) { AddPlantCameraView() }
            .task {
                if viewModel == nil {
                    viewModel = LibraryViewModel(plantRepository: PlantRepository(modelContext: modelContext))
                }
                viewModel?.load()
            }
            .onAppear {
                // Same fix as TodayView: `.task` only runs once per view lifetime, so a plant
                // added via the sheet does not appear here until the view reappears from scratch.
                AppLog.checkpoint.notice("Library: view appeared, reloading")
                viewModel?.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: LibraryViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView {
            filterBar(viewModel)

            LazyVGrid(columns: columns, spacing: DS.Space.sm) {
                ForEach(viewModel.filtered) { plant in
                    NavigationLink(value: plant.id) { plantCard(plant) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.xxl)
            .animation(DS.Motion.quick, value: viewModel.filter)
        }
        .background(DS.Color.surfaceSunken)
        .scrollContentBackground(.hidden)
        .searchable(text: $vm.searchText, prompt: String(localized: "library.search", defaultValue: "Buscar por nombre o especie"))
    }

    private func filterBar(_ viewModel: LibraryViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.xs) {
                filterChip(nil, label: String(localized: "library.filter.all", defaultValue: "Todas"), count: viewModel.count(for: nil), viewModel: viewModel)
                ForEach(DSWateringState.allCases, id: \.self) { state in
                    let n = viewModel.count(for: state)
                    if n > 0 { filterChip(state, label: state.label, count: n, viewModel: viewModel) }
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.xs)
        }
    }

    private func filterChip(_ state: DSWateringState?, label: String, count: Int, viewModel: LibraryViewModel) -> some View {
        let selected = viewModel.filter == state
        return Button {
            withAnimation(DS.Motion.quick) { viewModel.filter = selected ? nil : state }
        } label: {
            HStack(spacing: DS.Space.xxs) {
                if let state { Image(systemName: state.symbol).font(.system(size: 11, weight: .semibold)) }
                Text(label).font(DS.Text.caption.weight(.medium))
                Text("\(count)").font(.system(size: 11, weight: .semibold)).foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            }
            .frame(minHeight: 30)
            .padding(.horizontal, DS.Space.sm)
            .foregroundStyle(selected ? .white : (state?.tint ?? .primary))
            .background(Capsule().fill(selected ? (state?.tint ?? DS.Color.brand) : DS.Color.surface))
            .overlay(Capsule().strokeBorder(DS.Color.hairline, lineWidth: selected ? 0 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func plantCard(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PlantThumbView(plant: plant, size: 200, corner: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .clipped()

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(plant.name).font(DS.Text.cardTitle).lineLimit(1)
                if let species = plant.species {
                    Text(species).font(DS.Text.caption).italic().foregroundStyle(.secondary).lineLimit(1)
                }
                DSStatusBadge(state: plant.dsWateringState, detail: plant.wateringDetailText, compact: true).padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Space.sm)
        }
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(DS.Color.hairline, lineWidth: 0.5))
    }
}
