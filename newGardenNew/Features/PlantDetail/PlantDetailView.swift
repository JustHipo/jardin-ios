import SwiftUI
import SwiftData

/// M03: one scroll, no icon-only sub-tabs, photo at full width, and the AI presented
/// auditable — with sources, confidence in human language, and a way to discard the
/// correction. Structurally matches `Mockups/Screens/M03_PlantDetailMockup.swift`.
struct PlantDetailView: View {
    let plantId: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlantDetailViewModel?
    @State private var showChat = false
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    @State private var showAppliedMlPrompt = false
    @State private var appliedMlText = ""

    var body: some View {
        Group {
            if let viewModel, let plant = viewModel.plant {
                ScrollView {
                    VStack(spacing: DS.Space.md) {
                        hero(plant)
                        actions(viewModel, plant: plant)
                        aiCard(viewModel, plant: plant)
                        if settings.hasPets { toxicityCard(viewModel) }
                        improveCard(plant)
                        plantInfoCard(plant)
                        botanicalCard(plant)
                        historyCard(viewModel)
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.bottom, DS.Space.xxl)
                }
                .background(DS.Color.surfaceSunken)
                .scrollContentBackground(.hidden)
                .navigationTitle(plant.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarMenu(plant) }
                .sheet(isPresented: $showChat) { PlantChatView(plantId: plant.id) }
                .sheet(isPresented: $showEdit) {
                    PlantEditView(plant: plant, onSaved: { viewModel.load() })
                }
                .confirmationDialog(
                    String(localized: "detail.delete.confirmTitle", defaultValue: "¿Eliminar esta planta?"),
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "detail.menu.delete", defaultValue: "Eliminar planta"), role: .destructive) {
                        modelContext.delete(plant)
                        try? modelContext.save()
                        dismiss()
                    }
                } message: {
                    Text(String(localized: "detail.delete.confirmMessage", defaultValue: "Se borrará todo su historial de riego y fotos. Esto no se puede deshacer."))
                }
                .alert(
                    String(localized: "detail.appliedMl.title", defaultValue: "¿Cuánta agua le echaste?"),
                    isPresented: $showAppliedMlPrompt
                ) {
                    TextField(String(localized: "detail.appliedMl.placeholder", defaultValue: "ml (opcional)"), text: $appliedMlText)
                        .keyboardType(.numberPad)
                    Button(String(localized: "detail.appliedMl.confirm", defaultValue: "Registrar")) {
                        withAnimation(DS.Motion.quick) {
                            viewModel.water(appliedMl: Double(appliedMlText))
                        }
                        appliedMlText = ""
                    }
                    Button(String(localized: "detail.appliedMl.skip", defaultValue: "Omitir"), role: .cancel) {
                        withAnimation(DS.Motion.quick) { viewModel.water() }
                        appliedMlText = ""
                    }
                } message: {
                    Text(String(
                        localized: "detail.appliedMl.message",
                        defaultValue: "Si mediste tu regadera, decir cuántos ml aplicaste hace el cálculo más preciso. Es opcional, puedes omitirlo."
                    ))
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = PlantDetailViewModel(
                    plantId: plantId,
                    plantRepository: PlantRepository(modelContext: modelContext),
                    wateringRepository: WateringEventRepository(modelContext: modelContext),
                    orchestrator: dependencies?.makeOrchestrator(modelContext: modelContext)
                )
            }
            viewModel?.load()
        }
    }

    private func hero(_ plant: Plant) -> some View {
        VStack(spacing: DS.Space.sm) {
            PlantThumbView(plant: plant, size: 320, corner: DS.Radius.card)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))

            VStack(spacing: DS.Space.xxs) {
                if let species = plant.species {
                    Text(species).font(DS.Text.detail).italic().foregroundStyle(.secondary)
                }
                DSStatusBadge(state: plant.dsWateringState, detail: plant.wateringDetailText)
            }
        }
    }

    private func actions(_ viewModel: PlantDetailViewModel, plant: Plant) -> some View {
        HStack(spacing: DS.Space.sm) {
            DSPrimaryButton(title: String(localized: "detail.water", defaultValue: "Regar"), systemImage: "drop.fill") {
                showAppliedMlPrompt = true
            }
            Button { showChat = true } label: {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    Text(String(localized: "detail.ask", defaultValue: "Preguntar")).font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            .tint(DS.Color.aiAccent)
            .buttonBorderShape(.roundedRectangle(radius: DS.Radius.inner))
        }
    }

    // MARK: - AI card: rules always, AI additive, both named explicitly

    @ViewBuilder
    private func aiCard(_ viewModel: PlantDetailViewModel, plant: Plant) -> some View {
        DSCard(tint: DS.Color.aiSoft) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "sparkles").foregroundStyle(DS.Color.aiAccent)
                    Text(String(localized: "detail.ai.title", defaultValue: "Ajuste de riego")).font(DS.Text.cardTitle)
                    Spacer()
                    if viewModel.isAnalyzing { ProgressView().controlSize(.small) }
                }

                if let analysis = viewModel.latestAnalysis {
                    Text(analysisSummary(analysis, plant: plant)).font(DS.Text.body)

                    if let baseline = analysis.ruleBaselineDays, let correction = analysis.aiCorrectionDays, correction != 0 {
                        Text("Reglas: cada \(baseline) días. La IA lo ajustó a \(baseline + correction).")
                            .font(DS.Text.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let confidence = analysis.confidence, confidence != "n/a" {
                        DSConfidenceRow(level: confidenceLevel(confidence))
                    }

                    if analysis.aiCorrectionDays != nil, viewModel.adjustmentDecision == nil {
                        HStack(spacing: DS.Space.xs) {
                            Button(String(localized: "detail.ai.keep", defaultValue: "Mantener el ajuste")) {
                                withAnimation(DS.Motion.quick) { viewModel.acceptAdjustment(true) }
                            }
                            .buttonStyle(.borderedProminent).tint(DS.Color.aiAccent).controlSize(.small)

                            Button(String(localized: "detail.ai.revert", defaultValue: "Volver a las reglas")) {
                                withAnimation(DS.Motion.quick) { viewModel.acceptAdjustment(false) }
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                            Spacer()
                        }
                    }

                    // Once `latestAnalysis` exists, "Analizar ahora" below never renders again
                    // — found live, testing on-device: after editing pot size and material
                    // there was no way to get a fresh number without watering the plant or
                    // waiting for the background job. Editing data the rule engine reads
                    // should let you ask it to recompute.
                    Button(String(localized: "detail.ai.reanalyze", defaultValue: "Recalcular")) {
                        Task { await viewModel.runAnalysis() }
                    }
                    .font(DS.Text.caption.weight(.semibold))
                    .disabled(viewModel.isAnalyzing)
                } else {
                    Text(String(localized: "detail.ai.none", defaultValue: "Todavía no se ha calculado un ajuste para esta planta."))
                        .font(DS.Text.detail)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "detail.ai.analyze", defaultValue: "Analizar ahora")) {
                        Task { await viewModel.runAnalysis() }
                    }
                    .font(DS.Text.detail.weight(.semibold))
                }
            }
        }
    }

    /// The deterministic template, filled by the rule engine's number whether or not the AI
    /// ever narrates over it — this is the "plantilla primero" rule from the design
    /// discussion (docs/ANALISIS_IMPLEMENTACION.md section 3).
    private func analysisSummary(_ analysis: AIAnalysis, plant: Plant) -> String {
        if let reasoning = analysis.reasoning, !reasoning.isEmpty { return reasoning }
        let days = plant.effectiveCycleDays
        return "Cada \(days) días, calculado con el clima y la maceta de esta planta."
    }

    private func confidenceLevel(_ raw: String) -> DSConfidenceRow.Level {
        switch raw {
        case "high": .high
        case "low": .low
        default: .medium
        }
    }

    // MARK: - Pet safety: never render "unknown" as "safe"

    @ViewBuilder
    private func toxicityCard(_ viewModel: PlantDetailViewModel) -> some View {
        switch viewModel.petSafetyVerdict {
        case .toxic(let notes):
            DSCard {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    Image(systemName: "pawprint.fill").font(.title3).foregroundStyle(DS.Color.statusOverdue)
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        Text(String(localized: "detail.toxic.title", defaultValue: "Tóxica para tus mascotas"))
                            .font(DS.Text.cardTitle).foregroundStyle(DS.Color.statusOverdue)
                        if let notes {
                            Text(notes).font(DS.Text.detail).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        case .unknown:
            DSCard {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    Image(systemName: "questionmark.circle.fill").font(.title3).foregroundStyle(DS.Color.statusUnknown)
                    Text(String(localized: "detail.toxic.unknown", defaultValue: "Todavía no sabemos si es segura para tus mascotas."))
                        .font(DS.Text.detail).foregroundStyle(.secondary)
                }
            }
        case .safe:
            EmptyView()
        }
    }

    // MARK: - Free context, moved after saving (P8)

    private func improveCard(_ plant: Plant) -> some View {
        let missing = missingFields(plant)
        return Group {
            if !missing.isEmpty {
                DSCard(tint: DS.Color.aiSoft) {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        Text(String(localized: "detail.improve.title", defaultValue: "Mejora la precisión")).font(DS.Text.cardTitle)
                        Text(String(localized: "detail.improve.detail", defaultValue: "Cuanto más sepa de esta planta, menos tiene que suponer."))
                            .font(DS.Text.detail).foregroundStyle(.secondary)
                        HStack(spacing: DS.Space.xs) {
                            ForEach(missing, id: \.self) { field in
                                Button { showEdit = true } label: {
                                    HStack(spacing: 4) {
                                        Text(field).font(DS.Text.caption.weight(.medium))
                                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                                    }
                                    .padding(.horizontal, DS.Space.sm).frame(minHeight: 34)
                                    .foregroundStyle(DS.Color.brand)
                                    .background(DS.Color.brandSoft, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private func missingFields(_ plant: Plant) -> [String] {
        var fields: [String] = []
        if plant.containerDiameterCm == nil { fields.append(String(localized: "detail.improve.potSize", defaultValue: "Tamaño de maceta")) }
        if plant.containerMaterial == nil { fields.append(String(localized: "detail.improve.soilType", defaultValue: "Tipo de tierra")) }
        if plant.growthPhase == nil { fields.append(String(localized: "detail.improve.growthPhase", defaultValue: "Etapa de crecimiento")) }
        return fields
    }

    // MARK: - "Sobre esta planta": what PlantNet said about this exact specimen

    @ViewBuilder
    private func plantInfoCard(_ plant: Plant) -> some View {
        if plant.commonName != nil || plant.familyName != nil || plant.growthPhase != nil {
            DSCard {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    DSSectionHeader(title: String(localized: "detail.plantInfo.title", defaultValue: "Sobre esta planta"))
                    if let commonName = plant.commonName, commonName != plant.name {
                        infoRow(String(localized: "detail.plantInfo.commonName", defaultValue: "Nombre común"), commonName)
                    }
                    if let family = plant.familyName {
                        infoRow(String(localized: "detail.plantInfo.family", defaultValue: "Familia"), family)
                    }
                    if let phase = plant.growthPhase {
                        infoRow(String(localized: "detail.plantInfo.growthPhase", defaultValue: "Etapa"), phase.label)
                    }
                }
            }
        }
    }

    // MARK: - "Ficha botánica": what Trefle says about the species in general

    @ViewBuilder
    private func botanicalCard(_ plant: Plant) -> some View {
        if let trefle = plant.cachedTrefleData {
            let growth = trefle.growth
            let rows = botanicalRows(growth: growth, specifications: trefle.specifications)
            if !rows.isEmpty {
                DSCard {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        DSSectionHeader(title: String(localized: "detail.botanical.title", defaultValue: "Ficha botánica"))
                        Text(String(localized: "detail.botanical.subtitle", defaultValue: "Lo que Trefle sabe sobre esta especie en general."))
                            .font(DS.Text.caption).foregroundStyle(.secondary)
                        ForEach(rows, id: \.0) { label, value in
                            infoRow(label, value)
                        }
                    }
                }
            }
        }
    }

    /// Only the fields Trefle actually populated — its free tier is sparse, and an empty
    /// "Luz: —" row would look like a bug rather than an honestly-missing data point.
    private func botanicalRows(growth: TrefleGrowth?, specifications: TrefleSpecifications?) -> [(String, String)] {
        var rows: [(String, String)] = []
        if let light = growth?.light {
            rows.append((String(localized: "detail.botanical.light", defaultValue: "Luz (0-10)"), "\(light)"))
        }
        if let humidity = growth?.atmospheric_humidity {
            rows.append((String(localized: "detail.botanical.humidity", defaultValue: "Humedad ambiental (0-10)"), "\(humidity)"))
        }
        if let drought = growth?.drought_tolerance {
            rows.append((
                String(localized: "detail.botanical.drought", defaultValue: "Tolerancia a sequía"),
                drought
                    ? String(localized: "common.yes", defaultValue: "Sí")
                    : String(localized: "common.no", defaultValue: "No")
            ))
        }
        if let phMin = growth?.ph_minimum, let phMax = growth?.ph_maximum {
            rows.append((String(localized: "detail.botanical.ph", defaultValue: "pH de suelo"), "\(phMin) - \(phMax)"))
        }
        if let bloom = growth?.bloom_months, !bloom.isEmpty {
            rows.append((String(localized: "detail.botanical.bloom", defaultValue: "Floración"), bloom.joined(separator: ", ")))
        }
        if let harvest = growth?.days_to_harvest {
            rows.append((String(localized: "detail.botanical.harvest", defaultValue: "Días a cosecha"), "\(harvest)"))
        }
        if let habit = specifications?.growth_habit {
            rows.append((String(localized: "detail.botanical.habit", defaultValue: "Hábito de crecimiento"), habit))
        }
        return rows
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(DS.Text.detail).foregroundStyle(.secondary)
            Spacer(minLength: DS.Space.md)
            Text(value).font(DS.Text.detail).multilineTextAlignment(.trailing)
        }
    }

    private func historyCard(_ viewModel: PlantDetailViewModel) -> some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSSectionHeader(title: String(localized: "detail.history.title", defaultValue: "Historial"))
                if viewModel.recentEvents.isEmpty {
                    Text(String(localized: "detail.history.empty", defaultValue: "Sin riegos registrados todavía."))
                        .font(DS.Text.detail).foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.recentEvents.prefix(5)) { event in
                        HStack(spacing: DS.Space.sm) {
                            Circle().fill(DS.Color.hairline).frame(width: 6, height: 6)
                            Text(String(localized: "detail.history.watered", defaultValue: "Riego registrado")).font(DS.Text.detail)
                            Spacer()
                            Text(event.wateredAt.timeAgoDescription).font(DS.Text.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarMenu(_ plant: Plant) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(String(localized: "detail.menu.edit", defaultValue: "Editar"), systemImage: "pencil") { showEdit = true }
                Divider()
                Button(String(localized: "detail.menu.delete", defaultValue: "Eliminar planta"), systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}
