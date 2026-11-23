import SwiftUI
import SwiftData

/// M09: its own tab, because "esto se ve mal, ¿qué le pasa?" is a distinct intention from
/// the daily agenda (decision confirmed directly by the owner per the handoff).
struct HealthView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: HealthViewModel?
    @State private var showCamera = false
    @State private var plants: [Plant] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.md) {
                    diagnoseCTA
                    if let viewModel {
                        ForEach(viewModel.recentChecks) { check in checkCard(check) }
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.xxl)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .navigationTitle(String(localized: "tab.health", defaultValue: "Salud"))
            .sheet(isPresented: $showCamera) {
                CameraPicker(
                    onCapture: { data in
                        showCamera = false
                        if let plant = plants.first {
                            Task { await viewModel?.diagnose(plant: plant, photo: data) }
                        }
                    },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .task {
                if let dependencies {
                    if viewModel == nil {
                        viewModel = HealthViewModel(plantNetService: dependencies.plantNetService, modelContext: modelContext, aiRouter: dependencies.aiRouter)
                    }
                    plants = (try? PlantRepository(modelContext: modelContext).fetchAll()) ?? []
                    viewModel?.load()
                }
            }
            .onAppear {
                // Same fix as TodayView/LibraryView: without this, a plant added elsewhere
                // leaves the "Diagnosticar" button wrongly disabled (stale empty `plants`)
                // until this view is torn down and rebuilt.
                plants = (try? PlantRepository(modelContext: modelContext).fetchAll()) ?? []
                viewModel?.load()
            }
        }
    }

    private var diagnoseCTA: some View {
        DSCard {
            VStack(spacing: DS.Space.sm) {
                Image(systemName: "camera.viewfinder").font(.system(size: 40, weight: .light)).foregroundStyle(DS.Color.brand).padding(.top, DS.Space.xs)
                Text(String(localized: "health.cta.title", defaultValue: "Fotografía la parte que te preocupa")).font(DS.Text.sectionTitle).multilineTextAlignment(.center)
                Text(String(localized: "health.cta.detail", defaultValue: "Una hoja con manchas, un tallo blando. Cuanto más cerca, mejor.")).font(DS.Text.detail).foregroundStyle(.secondary).multilineTextAlignment(.center)

                if viewModel?.isDiagnosing == true {
                    ProgressView().padding(.top, DS.Space.xxs)
                } else {
                    DSPrimaryButton(title: String(localized: "health.cta.action", defaultValue: "Diagnosticar"), systemImage: "camera.fill") {
                        showCamera = true
                    }
                    .padding(.top, DS.Space.xxs)
                    .disabled(plants.isEmpty)
                }

                HStack(spacing: DS.Space.xs) {
                    DSSourceChip(source: "PlantNet", value: String(localized: "health.cta.diseaseDetection", defaultValue: "detección de enfermedades"), symbol: "leaf.fill")
                    DSSourceChip(source: String(localized: "health.cta.onDevice", defaultValue: "On-device"), value: String(localized: "health.cta.photosStayHere", defaultValue: "tus fotos no salen"), symbol: "lock.fill")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func checkCard(_ check: HealthCheck) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.sm) {
                    if let plant = check.plant {
                        PlantThumbView(plant: plant, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plant.name).font(DS.Text.cardTitle)
                            Text(check.checkedAt.timeAgoDescription).font(DS.Text.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let score = check.healthScore { scoreRing(score) }
                }
                Divider()
                if let diagnosis = check.diagnosis {
                    Text(diagnosis).font(DS.Text.detail)
                }
                if !check.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        Text(String(localized: "health.whatToDo", defaultValue: "Qué hacer")).font(DS.Text.cardTitle)
                        ForEach(check.recommendations, id: \.self) { step in
                            HStack(alignment: .top, spacing: DS.Space.xs) {
                                Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(DS.Color.brand).padding(.top, 4)
                                Text(step).font(DS.Text.detail)
                            }
                        }
                    }
                }
            }
        }
    }

    private func scoreRing(_ score: Int) -> some View {
        ZStack {
            Circle().stroke(DS.Color.hairline, lineWidth: 5)
            Circle().trim(from: 0, to: Double(score) / 10)
                .stroke(DS.Color.statusSoon, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(score)").font(.title3.bold())
                Text(String(localized: "health.outOf10", defaultValue: "de 10")).font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Salud \(score) de 10")
    }
}
