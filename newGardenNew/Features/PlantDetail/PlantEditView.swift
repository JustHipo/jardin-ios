import SwiftUI
import SwiftData
import os

/// The missing half of M03's toolbar menu and "mejora la precisión" chips — both were wired
/// to nothing (`Button(...) {}` for Editar, plain `Text` with no `Button` at all for the
/// chips). Found while explaining an unexpectedly long watering cycle: the fields that would
/// have corrected it (pot size, material) had no way to be entered after the 2-step add flow,
/// which is exactly the gap P8 says gets filled in here, "después de guardar".
struct PlantEditView: View {
    let plant: Plant
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String
    @State private var locationIndex: Int
    @State private var diameterText: String
    @State private var topDiameterText: String
    @State private var bottomDiameterText: String
    @State private var heightText: String
    @State private var material: String
    @State private var substrateType: SubstrateType?
    @State private var plantCount: Int
    @State private var notes: String
    @State private var growthPhase: GrowthPhase?

    private static let materialOptions: [(label: String, value: String?)] = [
        (String(localized: "edit.material.unknown", defaultValue: "No sé"), nil),
        (String(localized: "edit.material.plastic", defaultValue: "Plástico"), "plastic"),
        (String(localized: "edit.material.terracotta", defaultValue: "Terracota"), "terracotta"),
        (String(localized: "edit.material.ceramic", defaultValue: "Cerámica esmaltada"), "ceramic"),
    ]

    init(plant: Plant, onSaved: @escaping () -> Void = {}) {
        self.plant = plant
        self.onSaved = onSaved
        _name = State(initialValue: plant.name)
        _locationIndex = State(initialValue: AddPlantViewModel.locationOptions.firstIndex { $0.0 == plant.sunRequirement } ?? 0)
        _diameterText = State(initialValue: plant.containerDiameterCm.map { String(format: "%.0f", $0) } ?? "")
        _topDiameterText = State(initialValue: plant.containerTopDiameterCm.map { String(format: "%.0f", $0) } ?? "")
        _bottomDiameterText = State(initialValue: plant.containerBottomDiameterCm.map { String(format: "%.0f", $0) } ?? "")
        _heightText = State(initialValue: plant.containerHeightCm.map { String(format: "%.0f", $0) } ?? "")
        _material = State(initialValue: plant.containerMaterial ?? "")
        _substrateType = State(initialValue: plant.substrateType)
        _plantCount = State(initialValue: plant.containerPlantCount ?? 1)
        _notes = State(initialValue: plant.notes ?? "")
        _growthPhase = State(initialValue: plant.growthPhase)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "edit.section.name", defaultValue: "Nombre")) {
                    TextField(String(localized: "edit.name.placeholder", defaultValue: "Nombre de la planta"), text: $name)
                }

                Section(String(localized: "edit.section.location", defaultValue: "¿Dónde vive?")) {
                    Picker(String(localized: "edit.section.location", defaultValue: "¿Dónde vive?"), selection: $locationIndex) {
                        ForEach(Array(AddPlantViewModel.locationOptions.enumerated()), id: \.offset) { index, option in
                            Text(option.0).tag(index)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section {
                    HStack {
                        Text(String(localized: "edit.diameter", defaultValue: "Diámetro (si no mediste con regla)"))
                        Spacer()
                        TextField("18", text: $diameterText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    Picker(String(localized: "edit.materialLabel", defaultValue: "Material"), selection: $material) {
                        ForEach(Self.materialOptions, id: \.label) { option in
                            Text(option.label).tag(option.value ?? "")
                        }
                    }
                    Stepper(value: $plantCount, in: 1...20) {
                        HStack {
                            Text(String(localized: "edit.plantCount", defaultValue: "Plantas en esta maceta"))
                            Spacer()
                            Text("\(plantCount)").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "edit.section.container", defaultValue: "Maceta"))
                } footer: {
                    if plantCount > 1 {
                        Text(String(localized: "edit.plantCount.footer", defaultValue: "Varias plantas comparten la misma tierra, así que se agota más rápido — el riego se ajusta para reflejar eso."))
                    }
                }

                Section {
                    HStack {
                        Text(String(localized: "edit.topDiameter", defaultValue: "Diámetro superior"))
                        Spacer()
                        TextField("—", text: $topDiameterText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(String(localized: "edit.bottomDiameter", defaultValue: "Diámetro inferior"))
                        Spacer()
                        TextField("—", text: $bottomDiameterText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(String(localized: "edit.height", defaultValue: "Altura"))
                        Spacer()
                        TextField("—", text: $heightText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    Picker(String(localized: "edit.substrateLabel", defaultValue: "Sustrato"), selection: $substrateType) {
                        Text(String(localized: "edit.substrate.unknown", defaultValue: "No sé")).tag(SubstrateType?.none)
                        ForEach(SubstrateType.allCases, id: \.self) { substrate in
                            Text(substrate.displayName).tag(SubstrateType?.some(substrate))
                        }
                    }
                    if let note = substrateType?.confidenceNote {
                        Text(note).font(.footnote).foregroundStyle(.orange)
                    }
                } header: {
                    Text(String(localized: "edit.section.realGeometry", defaultValue: "Medición con regla (opcional, más preciso)"))
                } footer: {
                    Text(String(
                        localized: "edit.section.realGeometry.footer",
                        defaultValue: "Con estos tres datos y el sustrato, el cálculo usa el volumen real de tu maceta en vez de una estimación por el diámetro solo. Si los dejas vacíos, se sigue usando el diámetro de arriba."
                    ))
                }

                Section {
                    Picker(String(localized: "edit.growthPhase.label", defaultValue: "Etapa de crecimiento"), selection: $growthPhase) {
                        Text(String(localized: "edit.growthPhase.unknown", defaultValue: "No sé")).tag(GrowthPhase?.none)
                        ForEach(GrowthPhase.allCases, id: \.self) { phase in
                            Text(phase.label).tag(GrowthPhase?.some(phase))
                        }
                    }
                } header: {
                    Text(String(localized: "edit.section.growthPhase", defaultValue: "¿Cómo la ves ahora?"))
                } footer: {
                    Text(String(localized: "edit.growthPhase.footer", defaultValue: "Una planta floreciendo o dando frutos necesita más agua que una en reposo — esto ajusta el cálculo del riego."))
                }

                Section(String(localized: "edit.section.notes", defaultValue: "Notas")) {
                    TextField(String(localized: "edit.notes.placeholder", defaultValue: "Lo que sepas de esta planta"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(String(localized: "edit.title", defaultValue: "Editar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel", defaultValue: "Cancelar")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save", defaultValue: "Guardar")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        plant.name = name.trimmingCharacters(in: .whitespaces)
        plant.sunRequirement = AddPlantViewModel.locationOptions[safe: locationIndex]?.0
        plant.containerDiameterCm = Double(diameterText)
        plant.containerTopDiameterCm = Double(topDiameterText)
        plant.containerBottomDiameterCm = Double(bottomDiameterText)
        plant.containerHeightCm = Double(heightText)
        plant.containerMaterial = material.isEmpty ? nil : material
        plant.substrateType = substrateType
        plant.containerPlantCount = plantCount
        plant.growthPhase = growthPhase
        plant.notes = notes.isEmpty ? nil : notes
        plant.updatedAt = .now

        do {
            try modelContext.save()
            AppLog.checkpoint.notice("Edit: saved plant \(plant.id, privacy: .public), diameter=\(plant.containerDiameterCm.map { "\($0)" } ?? "nil", privacy: .public) material=\(plant.containerMaterial ?? "nil", privacy: .public)")
        } catch {
            AppLog.app.error("Failed to save plant edit: \(error, privacy: .public)")
        }

        onSaved()
        dismiss()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
