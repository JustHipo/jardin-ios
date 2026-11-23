import SwiftUI

/// M06, step 2 of 2. Everything but species and location is auto-filled, editable later.
///
/// Cambio del 13 de septiembre: un porcentaje no le sirve a nadie para decidir si esa es
/// su planta — la tarea real es COMPARAR contra fotos. Cada candidata trae ahora la tira
/// de fotos de referencia que PlantNet ya devuelve en la misma respuesta (ver
/// `PlantNetModels.swift`), y la foto propia queda fija arriba junto con el órgano que
/// PlantNet creyó reconocer, para que el usuario pueda detectar un órgano mal leído antes
/// de que arruine toda la identificación.
struct AddPlantConfirmView: View {
    @Bindable var viewModel: AddPlantViewModel
    var onFinished: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                if viewModel.suggestions.isEmpty {
                    DSCard {
                        Text(String(localized: "addPlant.noSuggestions", defaultValue: "No encontré coincidencias claras. Puedes intentar con otra foto o añadirla a mano desde el menú anterior."))
                            .font(DS.Text.detail).foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        DSSectionHeader(title: String(localized: "addPlant.isThisIt", defaultValue: "¿Es esta?"))
                        ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            candidateCard(index: index, suggestion: suggestion)
                        }
                        plantNetAttribution
                    }
                }

                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    DSSectionHeader(title: String(localized: "addPlant.whereDoesItLive", defaultValue: "¿Dónde vive?"))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.xs) {
                        ForEach(Array(viewModel.locationOptions.enumerated()), id: \.offset) { index, item in
                            locationCard(index: index, title: item.0, symbol: item.1)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 100)
        }
        .background(DS.Color.surfaceSunken)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { comparisonBar }
        .safeAreaInset(edge: .bottom) {
            DSPrimaryButton(title: String(localized: "addPlant.save", defaultValue: "Guardar planta"), systemImage: "checkmark") {
                viewModel.saveConfirmed()
                onFinished()
            }
            .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
            .background(.bar)
        }
        .navigationTitle(String(localized: "addPlant.confirmTitle", defaultValue: "Confirmar"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Barra de comparación fija

    /// La foto del usuario no se va con el scroll: comparar exige ver las dos cosas a la
    /// vez. Nombra además el órgano que PlantNet creyó ver — si se equivocó (una foto de
    /// planta entera leída como flor, por ejemplo), el usuario mirando su propia foto es
    /// el único que puede notarlo.
    private var comparisonBar: some View {
        HStack(spacing: DS.Space.sm) {
            if let photoData = viewModel.capturedPhoto, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.inner))
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.inner)
                    .fill(DS.Color.brandSoft)
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "camera.fill").foregroundStyle(DS.Color.brand))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "addPlant.yourPhoto", defaultValue: "Tu foto")).font(DS.Text.caption.weight(.semibold))
                if let organ = viewModel.predictedOrgan {
                    Text(String(localized: "addPlant.plantNetReadAs", defaultValue: "PlantNet la leyó como \(organ.plantNetOrganLabel)"))
                        .font(DS.Text.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(String(localized: "addPlant.compareHint", defaultValue: "Compárala con las de abajo"))
                        .font(DS.Text.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xs)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.Color.hairline).frame(height: 0.5)
        }
    }

    private func candidateCard(index: Int, suggestion: PlantNetResult) -> some View {
        let isSelected = viewModel.selectedSuggestionIndex == index || (viewModel.selectedSuggestionIndex == nil && suggestion.score > 0.5 && index == 0)
        return VStack(alignment: .leading, spacing: DS.Space.xs) {
            Button {
                withAnimation(DS.Motion.quick) { viewModel.selectedSuggestionIndex = index }
            } label: {
                HStack(spacing: DS.Space.sm) {
                    RoundedRectangle(cornerRadius: DS.Radius.thumb)
                        .fill(DS.Color.brandSoft)
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "leaf.fill").foregroundStyle(DS.Color.brand))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.species.commonNames?.first ?? suggestion.species.scientificName).font(DS.Text.cardTitle)
                        Text(suggestion.species.scientificName).font(DS.Text.caption).italic().foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(suggestion.score * 100))%").font(DS.Text.detail.weight(.bold))
                            .foregroundStyle(suggestion.score > 0.5 ? DS.Color.statusOK : .secondary)
                    }
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? DS.Color.brand : DS.Color.hairline)
                }
            }
            .buttonStyle(.plain)

            if let images = suggestion.images, !images.isEmpty {
                referenceStrip(images)
            }
        }
        .padding(DS.Space.sm)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(isSelected ? DS.Color.brand : DS.Color.hairline, lineWidth: isSelected ? 2 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.inner))
    }

    /// PlantNet returns every reference photo for a candidate tagged with the SAME organ
    /// its classifier assigned to the query photo — verified live, not one of each organ —
    /// so the organ is named once for the whole strip instead of once per thumbnail.
    private func referenceStrip(_ images: [PlantNetImage]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            if let organ = images.first?.organ {
                Text("\(organ.plantNetOrganLabelPlural) \(String(localized: "addPlant.ofThisSpecies", defaultValue: "de esta especie")), \(images.count)")
                    .font(DS.Text.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.xs) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                        AsyncImage(url: URL(string: image.url.m ?? image.url.s ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            case .failure:
                                Rectangle().fill(DS.Color.hairline.opacity(0.3))
                            default:
                                Rectangle().fill(DS.Color.hairline.opacity(0.15))
                                    .overlay(ProgressView())
                            }
                        }
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.inner))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.inner))

            Text(attributionCaption(for: images))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    /// PlantNet's CC BY-SA license requires citing platform, license and author for every
    /// photo shown — not optional, not a footnote. `citation` already arrives pre-formatted
    /// ("Autor / Pl@ntNet, cc-by-sa"); this just avoids repeating the same author twice.
    private func attributionCaption(for images: [PlantNetImage]) -> String {
        let uniqueCitations = NSOrderedSet(array: images.compactMap(\.citation)).array as? [String] ?? []
        let prefix = String(localized: "addPlant.photosBy", defaultValue: "Fotos:")
        return "\(prefix) \(uniqueCitations.joined(separator: " · "))"
    }

    private var plantNetAttribution: some View {
        Text(String(localized: "addPlant.poweredByPlantNet", defaultValue: "Identificación por Pl@ntNet"))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
    }

    private func locationCard(index: Int, title: String, symbol: String) -> some View {
        let isSelected = viewModel.locationIndex == index
        return Button {
            withAnimation(DS.Motion.quick) { viewModel.locationIndex = index }
        } label: {
            VStack(spacing: DS.Space.xs) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(DS.Text.caption.weight(.medium)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .foregroundStyle(isSelected ? DS.Color.brand : .primary)
            .background(isSelected ? DS.Color.brandSoft : DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(isSelected ? DS.Color.brand : DS.Color.hairline, lineWidth: isSelected ? 2 : 0.5))
        }
        .buttonStyle(.plain)
    }
}
