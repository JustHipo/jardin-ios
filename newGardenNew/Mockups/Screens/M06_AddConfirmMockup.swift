#if DEBUG
import SwiftUI

/// P8: Paso 2 de 2. Confirmar especie y donde vive.
///
/// Cambio del 13 de septiembre: un porcentaje de confianza no le sirve de nada a una
/// persona para decidir si esa es su planta. Lo que necesita es COMPARAR. Por eso cada
/// candidata trae fotos de referencia y la foto del usuario queda fijada arriba.
///
/// Corregido el mismo dia contra la API real: PlantNet devuelve las imagenes solo si se
/// pide `include-related-images=true`, y TODAS son del mismo organo que el clasificador
/// detecto en la foto del usuario. Asi que la tira no mezcla organos: son N fotos del
/// mismo organo, que para comparar es mejor. El organo se nombra una vez, no por foto.
struct M06_AddConfirmMockup: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?
    @State private var location = 0
    @State private var expandedReference: UUID?

    private let locations: [(String, String)] = [
        ("Interior luminoso", "sun.max"),
        ("Interior sombrío", "cloud"),
        ("Exterior sol", "sun.max.fill"),
        ("Exterior sombra", "tree.fill"),
    ]

    private var selectedSuggestion: MockData.Suggestion? {
        MockData.suggestions.first { $0.id == selected } ?? MockData.suggestions.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    candidatesSection
                    locationSection
                    autoFilled
                }
                .padding(.bottom, 100)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { comparisonBar }
            .safeAreaInset(edge: .bottom) {
                DSPrimaryButton(title: "Guardar planta", systemImage: "checkmark")
                    .padding(.horizontal, DS.Space.md)
                    .padding(.vertical, DS.Space.sm)
                    .background(.bar)
            }
            .navigationTitle("¿Cuál es?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Atrás") { dismiss() } }
            }
        }
    }

    // MARK: - Barra de comparación fija

    /// La foto del usuario no se va con el scroll. Comparar exige ver las dos cosas a la vez.
    private var comparisonBar: some View {
        HStack(spacing: DS.Space.sm) {
            DSPlantThumb(name: "foto del usuario", symbol: "camera.fill", size: 56, corner: DS.Radius.inner)

            VStack(alignment: .leading, spacing: 1) {
                Text("Tu foto").font(DS.Text.caption.weight(.semibold))
                // Decirle al usuario COMO leyo PlantNet su foto. Si se equivoco de organo,
                // la identificacion entera va mal encaminada y conviene que pueda verlo.
                Text("PlantNet la leyó como **\(MockData.detectedOrgan.name)**")
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button { } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.viewfinder")
                    Text("Otro ángulo").font(DS.Text.caption.weight(.medium))
                }
                .frame(height: 44)
                .padding(.horizontal, DS.Space.xs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Añadir una foto de otro ángulo")
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xs)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.hairline).frame(height: 0.5)
        }
    }

    // MARK: - Candidatas

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSSectionHeader(
                title: "Coincidencias",
                count: MockData.suggestions.count,
                accessory: "PlantNet"
            )
            .padding(.horizontal, DS.Space.md)

            VStack(spacing: DS.Space.sm) {
                ForEach(MockData.suggestions) { suggestion in
                    candidateCard(suggestion)
                }
            }
            .padding(.horizontal, DS.Space.md)

            attribution
                .padding(.horizontal, DS.Space.md)

            Button { } label: {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "questionmark.circle")
                    Text("Ninguna se parece").font(DS.Text.detail.weight(.medium))
                }
                .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: DS.Radius.inner))
            .padding(.horizontal, DS.Space.md)
        }
        .padding(.top, DS.Space.sm)
    }

    private func candidateCard(_ suggestion: MockData.Suggestion) -> some View {
        let isSelected = (selected ?? MockData.suggestions.first?.id) == suggestion.id

        return Button {
            withAnimation(DS.Motion.quick) { selected = suggestion.id }
        } label: {
            VStack(alignment: .leading, spacing: DS.Space.sm) {

                // Fotos de referencia. Todas del mismo organo, asi que se nombra una vez.
                HStack(spacing: DS.Space.xxs) {
                    Text("\(MockData.detectedOrgan.plural) de esta especie")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(suggestion.references.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.xs) {
                        ForEach(suggestion.references) { reference in
                            referencePhoto(reference, species: suggestion.scientific)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.inner))

                HStack(alignment: .top, spacing: DS.Space.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.common)
                            .font(DS.Text.cardTitle)
                            .multilineTextAlignment(.leading)
                        Text(suggestion.scientific)
                            .font(DS.Text.caption).italic()
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    confidencePill(suggestion.confidence)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? DS.Color.brand : DS.Color.hairline)
                }
            }
            .padding(DS.Space.sm)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .strokeBorder(isSelected ? DS.Color.brand : DS.Color.hairline,
                                  lineWidth: isSelected ? 2 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(suggestion.common), \(suggestion.scientific), \(suggestion.confidence) por ciento de coincidencia, \(suggestion.references.count) fotos de referencia de \(MockData.detectedOrgan.name)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func referencePhoto(_ reference: MockData.Reference, species: String) -> some View {
        DSPlantThumb(
            name: species + reference.author,
            symbol: reference.symbol,
            size: 124,
            corner: 0
        )
        .frame(width: 124, height: 124)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.inner))
        .accessibilityLabel("Foto de referencia de \(species) por \(reference.author)")
    }

    private func confidencePill(_ value: Int) -> some View {
        let strong = value > 50
        return VStack(spacing: 0) {
            Text("\(value)%")
                .font(DS.Text.detail.weight(.bold))
            Text("coincide")
                .font(.system(size: 9))
        }
        .foregroundStyle(strong ? DS.Color.statusOK : .secondary)
        .padding(.horizontal, DS.Space.xs)
        .padding(.vertical, 4)
        .background(
            (strong ? DS.Color.statusOK : DS.Color.statusUnknown).opacity(0.12),
            in: RoundedRectangle(cornerRadius: DS.Radius.chip)
        )
    }

    /// Obligatoria: las fotos de PlantNet son CC BY-SA y exigen citar plataforma,
    /// licencia y autor.
    private var attribution: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Fotos de referencia: Pl@ntNet, cc-by-sa")
                .font(.system(size: 11))
            Text("m.rousselot · j.tinguely · a.benitez · p.bonnet · c.mora y otros")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Ubicación

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSSectionHeader(title: "¿Dónde vive?")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.xs) {
                ForEach(Array(locations.enumerated()), id: \.offset) { index, item in
                    locationCard(index: index, title: item.0, symbol: item.1)
                }
            }
        }
        .padding(.horizontal, DS.Space.md)
    }

    private func locationCard(index: Int, title: String, symbol: String) -> some View {
        let isSelected = location == index
        return Button {
            withAnimation(DS.Motion.quick) { location = index }
        } label: {
            VStack(spacing: DS.Space.xs) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(DS.Text.caption.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .foregroundStyle(isSelected ? DS.Color.brand : .primary)
            .background(isSelected ? DS.Color.brandSoft : DS.Color.surface,
                        in: RoundedRectangle(cornerRadius: DS.Radius.inner))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.inner)
                    .strokeBorder(isSelected ? DS.Color.brand : DS.Color.hairline,
                                  lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var autoFilled: some View {
        DSCard(tint: DS.Color.aiSoft) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "sparkles").foregroundStyle(DS.Color.aiAccent)
                    Text("Relleno automático").font(DS.Text.cardTitle)
                }
                Text("\(selectedSuggestion?.common ?? "Monstera"): riego cada 7 días · luz indirecta · tóxica para gatos y perros")
                    .font(DS.Text.detail)
                Text("Todo esto es editable después desde la ficha de la planta.")
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Space.md)
    }
}

#Preview("Confirmar: claro") { M06_AddConfirmMockup() }
#Preview("Confirmar: oscuro") { M06_AddConfirmMockup().preferredColorScheme(.dark) }
#endif
