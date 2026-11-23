import SwiftUI
import SwiftData
import os

/// M01. See docs/HANDOFF.md 3.2 and P2: the entry screen is an agenda, not an alphabetical
/// inventory. Structurally identical to `Mockups/Screens/M01_TodayMockup.swift`, wired to
/// real SwiftData instead of `MockData`.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(AppSettings.self) private var settings
    @State private var viewModel: TodayViewModel?
    @State private var showAllFine = false
    @State private var showAddPlant = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "tab.today", defaultValue: "Hoy"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddPlant = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(String(localized: "today.addPlant", defaultValue: "Añadir planta"))
                }
            }
            .sheet(isPresented: $showAddPlant, onDismiss: {
                // `.onAppear` below does NOT fire here: this view never actually disappeared,
                // it was merely covered by the sheet. Sheet dismissal needs its own reload —
                // found live, testing on-device: the plant saved correctly (confirmed in the
                // log) but Hoy kept showing "vacío" because nothing told it to refetch.
                AppLog.checkpoint.notice("Today: add-plant sheet dismissed")
                viewModel?.load()
            }) { AddPlantCameraView() }
            .navigationDestination(for: UUID.self) { plantId in
                PlantDetailView(plantId: plantId)
            }
            .task {
                if viewModel == nil {
                    viewModel = TodayViewModel(
                        plantRepository: PlantRepository(modelContext: modelContext),
                        wateringRepository: WateringEventRepository(modelContext: modelContext),
                        settings: settings
                    )
                }
                viewModel?.load()
            }
            .onAppear {
                // `.task` above only runs once per view lifetime. Without this, a plant added
                // via the sheet, or watered from the plant detail screen, does not show up
                // here until the view is torn down and rebuilt (e.g. switching tabs and back)
                // — the exact bug reported on-device.
                AppLog.checkpoint.notice("Today: view appeared, reloading")
                viewModel?.load()
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: TodayViewModel) -> some View {
        ScrollView {
            VStack(spacing: DS.Space.lg) {
                if !settings.hasLocation {
                    locationPrompt
                }

                section(title: String(localized: "today.section.today", defaultValue: "Hoy"), plants: viewModel.overdue, viewModel: viewModel)
                section(title: String(localized: "today.section.thisWeek", defaultValue: "Esta semana"), plants: viewModel.soon, viewModel: viewModel)
                fineSection(viewModel)

                if viewModel.overdue.isEmpty && viewModel.soon.isEmpty && viewModel.fine.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.xs)
            .padding(.bottom, 100)
        }
        .background(DS.Color.surfaceSunken)
        .scrollContentBackground(.hidden)

        if let undoPlant = viewModel.undoVisibleFor {
            undoToast(plant: undoPlant, viewModel: viewModel)
        }
    }

    private var locationPrompt: some View {
        DSCard(tint: DS.Color.brandSoft) {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: "location.fill").font(.title2).foregroundStyle(DS.Color.brand)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(String(localized: "today.location.title", defaultValue: "Activa tu ubicación"))
                        .font(DS.Text.cardTitle)
                    Text(String(localized: "today.location.detail", defaultValue: "Se usa para el clima, que ajusta el riego. Nunca sale del dispositivo."))
                        .font(DS.Text.detail)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(String(localized: "today.location.action", defaultValue: "Activar")) {
                    dependencies?.locationService.requestPermission()
                }
                .font(DS.Text.detail.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private func section(title: String, plants: [Plant], viewModel: TodayViewModel) -> some View {
        if !plants.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSSectionHeader(title: title, count: plants.count)
                VStack(spacing: DS.Space.xs) {
                    ForEach(plants) { plant in
                        NavigationLink(value: plant.id) { taskRow(plant, viewModel: viewModel) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func fineSection(_ viewModel: TodayViewModel) -> some View {
        Group {
            if !viewModel.fine.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    Button {
                        withAnimation(DS.Motion.quick) { showAllFine.toggle() }
                    } label: {
                        HStack {
                            DSSectionHeader(title: String(localized: "today.section.fine", defaultValue: "Todo en orden"), count: viewModel.fine.count)
                            Image(systemName: showAllFine ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showAllFine {
                        VStack(spacing: DS.Space.xs) {
                            ForEach(viewModel.fine) { plant in
                                NavigationLink(value: plant.id) { taskRow(plant, viewModel: viewModel) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func taskRow(_ plant: Plant, viewModel: TodayViewModel) -> some View {
        DSCard {
            HStack(spacing: DS.Space.sm) {
                PlantThumbView(plant: plant, size: 52)

                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    HStack(spacing: DS.Space.xxs) {
                        Text(plant.name).font(DS.Text.cardTitle)
                        if PetSafetyVerdict(isToxic: plant.isToxicToDogs == true || plant.isToxicToCats == true, notes: nil).isToxic, settings.hasPets {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Color.statusOverdue)
                                .accessibilityLabel(String(localized: "plant.toxicToPets", defaultValue: "Tóxica para mascotas"))
                        }
                    }
                    if let sun = plant.sunRequirement {
                        Text(sun).font(DS.Text.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    DSStatusBadge(state: plant.dsWateringState, detail: plant.wateringDetailText, compact: true)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(DS.Motion.quick) { viewModel.water(plant) }
                } label: {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(DS.Color.brand)
                        .background(Circle().fill(DS.Color.brandSoft))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Regar \(plant.name)")
                .sensoryFeedback(.success, trigger: viewModel.undoVisibleFor?.id == plant.id)
            }
        }
    }

    private func undoToast(plant: Plant, viewModel: TodayViewModel) -> some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: "drop.fill").foregroundStyle(DS.Color.brand)
            Text(String(localized: "today.undo.confirmed", defaultValue: "Riego registrado")).font(DS.Text.detail)
            Spacer()
            Button(String(localized: "today.undo.action", defaultValue: "Deshacer")) {
                withAnimation(DS.Motion.quick) { viewModel.undo(plant) }
            }
            .font(DS.Text.detail.weight(.semibold))
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .dsGlass(in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .padding(.horizontal, DS.Space.md)
        .padding(.bottom, DS.Space.md)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task {
            try? await Task.sleep(for: .seconds(5))
            viewModel.dismissUndo()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "leaf.fill").font(.system(size: 48, weight: .light)).foregroundStyle(DS.Color.brand)
            Text(String(localized: "today.empty.title", defaultValue: "Tu jardín está vacío"))
                .font(DS.Text.sectionTitle)
            DSPrimaryButton(title: String(localized: "today.empty.cta", defaultValue: "Añadir mi primera planta"), systemImage: "camera.fill") {
                showAddPlant = true
            }
        }
        .padding(.top, DS.Space.xxl)
    }
}
