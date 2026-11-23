#if DEBUG
import SwiftUI

/// La biblioteca completa. Sigue existiendo, pero un nivel más adentro: deja de
/// ser la pantalla de entrada. Cuadrícula con la foto grande, porque la foto de
/// la planta es el contenido emocional de la app y hoy se muestra a 60 puntos.
struct M02_LibraryMockup: View {
    @State private var filter: DSWateringState? = nil
    @State private var showAdd = false
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: DS.Space.sm)]

    private var filtered: [MockData.Plant] {
        guard let filter else { return MockData.plants }
        return MockData.plants.filter { $0.state == filter }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                filterBar

                LazyVGrid(columns: columns, spacing: DS.Space.sm) {
                    ForEach(filtered) { plant in
                        plantCard(plant)
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.xxl)
                .animation(DS.Motion.quick, value: filter)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .navigationTitle("Plantas")
            .searchable(text: .constant(""), prompt: "Buscar por nombre o especie")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Añadir planta")
                }
            }
            .fullScreenCover(isPresented: $showAdd) { M05_AddCameraMockup() }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.xs) {
                filterChip(nil, label: "Todas", count: MockData.plants.count)
                ForEach(DSWateringState.allCases, id: \.self) { state in
                    let n = MockData.plants.filter { $0.state == state }.count
                    if n > 0 { filterChip(state, label: state.label, count: n) }
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.xs)
        }
    }

    private func filterChip(_ state: DSWateringState?, label: String, count: Int) -> some View {
        let selected = filter == state
        return Button {
            withAnimation(DS.Motion.quick) { filter = selected ? nil : state }
        } label: {
            HStack(spacing: DS.Space.xxs) {
                if let state {
                    Image(systemName: state.symbol).font(.system(size: 11, weight: .semibold))
                }
                Text(label).font(DS.Text.caption.weight(.medium))
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
            }
            .frame(minHeight: 30)
            .padding(.horizontal, DS.Space.sm)
            .foregroundStyle(selected ? .white : (state?.tint ?? .primary))
            .background(
                Capsule().fill(selected ? (state?.tint ?? DS.Color.brand) : DS.Color.surface)
            )
            .overlay(Capsule().strokeBorder(DS.Color.hairline, lineWidth: selected ? 0 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func plantCard(_ plant: MockData.Plant) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DSPlantThumb(name: plant.name, symbol: plant.symbol, size: 200, corner: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .clipped()

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(plant.name)
                    .font(DS.Text.cardTitle)
                    .lineLimit(1)
                Text(plant.species)
                    .font(DS.Text.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                DSStatusBadge(state: plant.state, detail: plant.detail, compact: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Space.sm)
        }
        .background(DS.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
        )
    }
}

#Preview("Biblioteca, claro") { M02_LibraryMockup() }
#Preview("Biblioteca, oscuro") { M02_LibraryMockup().preferredColorScheme(.dark) }
#endif
