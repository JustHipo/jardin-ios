#if DEBUG
import SwiftUI

/// P4: La ficha de planta: un solo scroll (fuera las 3 sub-pestañas con solo
/// iconos), foto a ancho completo, y la IA presentada de forma auditable: con
/// fuentes, confianza en lenguaje humano y opción de descartar el ajuste.
struct M03_PlantDetailMockup: View {
    private let plant = MockData.monstera
    @State private var adjustmentAccepted: Bool? = nil
    @State private var showChat = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.md) {
                    hero
                    actions
                    aiCard
                    toxicityCard
                    improveCard
                    historyCard
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.xxl)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .navigationTitle(plant.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Editar", systemImage: "pencil") {}
                        Button("Mover de ubicación", systemImage: "arrow.left.arrow.right") {}
                        Divider()
                        Button("Eliminar planta", systemImage: "trash", role: .destructive) {}
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showChat) { M04_PlantChatMockup() }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: DS.Space.sm) {
            DSPlantThumb(name: plant.name, symbol: plant.symbol, size: 320, corner: DS.Radius.card)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))

            VStack(spacing: DS.Space.xxs) {
                Text(plant.species)
                    .font(DS.Text.detail).italic()
                    .foregroundStyle(.secondary)
                DSStatusBadge(state: plant.state, detail: plant.detail)
            }
        }
    }

    // MARK: - Acciones

    private var actions: some View {
        HStack(spacing: DS.Space.sm) {
            DSPrimaryButton(title: "Regar", systemImage: "drop.fill")
            Button {
                showChat = true
            } label: {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    Text("Preguntar").font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            .tint(DS.Color.aiAccent)
            .buttonBorderShape(.roundedRectangle(radius: DS.Radius.inner))
        }
    }

    // MARK: - IA auditable

    private var aiCard: some View {
        DSCard(tint: DS.Color.aiSoft) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "sparkles").foregroundStyle(DS.Color.aiAccent)
                    Text("Ajuste automático de ayer")
                        .font(DS.Text.cardTitle)
                    Spacer()
                    Text("06:04").font(DS.Text.caption).foregroundStyle(.tertiary)
                }

                Text("Pasé el ciclo de **7 a 5 días**. Vienen 5 días sobre 30° sin lluvia y tu Monstera está en una maceta de 18 cm, que se seca rápido con ese calor.")
                    .font(DS.Text.body)

                DSConfidenceRow(level: .medium)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.xs) {
                        DSSourceChip(source: "WeatherKit", value: "32° · 0 mm", symbol: "cloud.sun.fill")
                        DSSourceChip(source: "Trefle", value: "humedad 5/10", symbol: "leaf.fill")
                        DSSourceChip(source: "Tu historial", value: "6 riegos / 30 d", symbol: "clock.fill")
                    }
                }

                if adjustmentAccepted == nil {
                    HStack(spacing: DS.Space.xs) {
                        Button("Mantener el ajuste") {
                            withAnimation(DS.Motion.quick) { adjustmentAccepted = true }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.Color.aiAccent)
                        .controlSize(.small)

                        Button("Volver a 7 días") {
                            withAnimation(DS.Motion.quick) { adjustmentAccepted = false }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Spacer()
                    }
                } else {
                    Label(
                        adjustmentAccepted == true ? "Ciclo en 5 días" : "Ciclo devuelto a 7 días",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(DS.Text.caption)
                    .foregroundStyle(DS.Color.statusOK)
                }
            }
        }
    }

    // MARK: - Toxicidad

    private var toxicityCard: some View {
        DSCard {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: "pawprint.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.statusOverdue)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text("Tóxica para tu gato")
                        .font(DS.Text.cardTitle)
                        .foregroundStyle(DS.Color.statusOverdue)
                    Text("Contiene cristales de oxalato de calcio. La ingestión causa irritación bucal y salivación. Mantenla fuera de su alcance.")
                        .font(DS.Text.detail)
                        .foregroundStyle(.secondary)
                    DSSourceChip(source: "Trefle", value: "toxicity: medium", symbol: "exclamationmark.shield.fill")
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - El contexto libre, movido a después de guardar

    private var improveCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack {
                    Text("Mejora la precisión").font(DS.Text.cardTitle)
                    Spacer()
                    Text("2 de 4").font(DS.Text.caption).foregroundStyle(.secondary)
                }

                ProgressView(value: 0.5)
                    .tint(DS.Color.brand)

                Text("Cuanto más sepa de esta planta en concreto, menos tiene que suponer. Faltan dos datos:")
                    .font(DS.Text.detail)
                    .foregroundStyle(.secondary)

                HStack(spacing: DS.Space.xs) {
                    improveChip("Tamaño de maceta", "circle.grid.2x2")
                    improveChip("Tipo de tierra", "square.3.layers.3d")
                }
            }
        }
    }

    private func improveChip(_ title: String, _ symbol: String) -> some View {
        Button { } label: {
            HStack(spacing: DS.Space.xxs) {
                Image(systemName: symbol).font(.caption)
                Text(title).font(DS.Text.caption.weight(.medium))
                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
            }
            .frame(minHeight: 34)
            .padding(.horizontal, DS.Space.sm)
            .foregroundStyle(DS.Color.brand)
            .background(DS.Color.brandSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Historial

    private var historyCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSSectionHeader(title: "Historial", accessory: "Ver todo")
                ForEach(Array(zip(
                    ["Hoy", "Hace 5 días", "Hace 11 días"],
                    ["Riego registrado", "Riego registrado", "Chequeo de salud: 7/10"]
                )), id: \.0) { when, what in
                    HStack(spacing: DS.Space.sm) {
                        Circle().fill(DS.Color.hairline).frame(width: 6, height: 6)
                        Text(what).font(DS.Text.detail)
                        Spacer()
                        Text(when).font(DS.Text.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

#Preview("Ficha, claro") { M03_PlantDetailMockup() }
#Preview("Ficha, oscuro") { M03_PlantDetailMockup().preferredColorScheme(.dark) }
#endif
