import SwiftUI
import SwiftData

/// M05, step 1 of 2. Identification starts the moment a photo is captured.
struct AddPlantCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: AddPlantViewModel?
    // Was `true` (auto-opens the picker on appear) — but `CameraPicker.onCancel` dismisses
    // the WHOLE add-plant flow, not just the picker, so there was no way back to a screen
    // where the ··· menu (No la reconoce / Estoy sembrando semillas) is reachable: it sits
    // in this view's own toolbar, which a sheet on top of it makes untappable. Found live
    // trying to test M07. Starting closed and making the prompt itself the "open camera"
    // tap keeps the menu always reachable.
    @State private var showCamera = false
    @State private var goToConfirm = false
    @State private var goToUnrecognized = false
    @State private var goToSeed = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.surfaceSunken.ignoresSafeArea()

                if let viewModel {
                    if viewModel.capturedPhoto == nil {
                        prompt
                    } else {
                        statusOverlay(viewModel)
                    }
                }
            }
            .navigationTitle(String(localized: "addPlant.title", defaultValue: "Añadir planta"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(String(localized: "addPlant.menu.notRecognized", defaultValue: "No la reconoce, añadir a mano"), systemImage: "pencil") {
                            goToUnrecognized = true
                        }
                        Button(String(localized: "addPlant.menu.seed", defaultValue: "Estoy sembrando semillas"), systemImage: "circle.grid.cross") {
                            goToSeed = true
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(
                    onCapture: { data in
                        showCamera = false
                        Task {
                            await viewModel?.identify(photo: data)
                            goToConfirm = true
                        }
                    },
                    onCancel: {
                        showCamera = false
                        dismiss()
                    }
                )
                .ignoresSafeArea()
            }
            .navigationDestination(isPresented: $goToConfirm) {
                if let viewModel { AddPlantConfirmView(viewModel: viewModel, onFinished: { dismiss() }) }
            }
            .navigationDestination(isPresented: $goToUnrecognized) {
                if let viewModel { AddPlantUnrecognizedView(viewModel: viewModel, onFinished: { dismiss() }) }
            }
            .navigationDestination(isPresented: $goToSeed) {
                if let viewModel { AddPlantSeedView(viewModel: viewModel, onFinished: { dismiss() }) }
            }
            .task {
                if viewModel == nil, let dependencies {
                    viewModel = AddPlantViewModel(
                        plantRepository: PlantRepository(modelContext: modelContext),
                        plantNetService: dependencies.plantNetService,
                        trefleService: dependencies.trefleService,
                        modelContext: modelContext
                    )
                }
            }
        }
    }

    private var prompt: some View {
        Button {
            showCamera = true
        } label: {
            VStack(spacing: DS.Space.md) {
                Image(systemName: "camera.fill").font(.system(size: 48, weight: .light)).foregroundStyle(DS.Color.brand)
                Text(String(localized: "addPlant.prompt", defaultValue: "Encuadra la planta entera, con la maceta si se puede"))
                    .font(DS.Text.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Space.lg)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusOverlay(_ viewModel: AddPlantViewModel) -> some View {
        if viewModel.isIdentifying {
            HStack(spacing: DS.Space.xs) {
                ProgressView().controlSize(.small)
                Text(String(localized: "addPlant.searching", defaultValue: "Buscando la especie")).font(DS.Text.detail)
            }
            .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
            .background(.black.opacity(0.35), in: Capsule())
            .foregroundStyle(.white)
        }
    }
}
