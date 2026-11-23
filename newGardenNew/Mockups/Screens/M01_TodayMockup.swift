#if DEBUG
import SwiftUI

/// P2: La pantalla principal deja de ser un inventario alfabético y pasa a
/// responder la pregunta que trae al usuario a la app: ¿tengo que hacer algo?
struct M01_TodayMockup: View {
    @State private var watered: Set<UUID> = []
    @State private var undoVisible = false
    @State private var showAllFine = false
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: DS.Space.lg) {
                        weatherBanner

                        section(title: "Hoy", plants: MockData.overdue + MockData.soon.prefix(1))

                        section(title: "Esta semana", plants: Array(MockData.soon.dropFirst()))

                        fineSection
                    }
                    .padding(.horizontal, DS.Space.md)
                    .padding(.top, DS.Space.xs)
                    .padding(.bottom, 100)
                }
                .background(DS.Color.surfaceSunken)
                .scrollContentBackground(.hidden)

                if undoVisible { undoToast }
            }
            .navigationTitle("Hoy")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Añadir planta")
                }
            }
            .fullScreenCover(isPresented: $showAdd) { M05_AddCameraMockup() }
        }
    }

    // MARK: - Weather in context, not weather as data

    private var weatherBanner: some View {
        DSCard(tint: DS.Color.brandSoft) {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(DS.Color.statusSoon)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text("32° y sin lluvia prevista en 5 días")
                        .font(DS.Text.cardTitle)
                    Text("Adelanté el riego de 3 plantas de exterior. Toca para ver cuáles.")
                        .font(DS.Text.detail)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(title: String, plants: [MockData.Plant]) -> some View {
        if !plants.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSSectionHeader(title: title, count: plants.count)
                VStack(spacing: DS.Space.xs) {
                    ForEach(plants) { plant in
                        taskRow(plant)
                    }
                }
            }
        }
    }

    private var fineSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Button {
                withAnimation(DS.Motion.quick) { showAllFine.toggle() }
            } label: {
                HStack {
                    DSSectionHeader(title: "Todo en orden", count: MockData.fine.count)
                    Image(systemName: showAllFine ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showAllFine {
                VStack(spacing: DS.Space.xs) {
                    ForEach(MockData.fine) { taskRow($0) }
                }
            }
        }
    }

    // MARK: - Row: one tap to water, with undo instead of confirmation

    private func taskRow(_ plant: MockData.Plant) -> some View {
        let done = watered.contains(plant.id)
        return DSCard {
            HStack(spacing: DS.Space.sm) {
                DSPlantThumb(name: plant.name, symbol: plant.symbol, size: 52)

                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    HStack(spacing: DS.Space.xxs) {
                        Text(plant.name).font(DS.Text.cardTitle)
                        if plant.toxicToPets {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Color.statusOverdue)
                                .accessibilityLabel("Tóxica para mascotas")
                        }
                    }
                    Text(plant.location)
                        .font(DS.Text.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    DSStatusBadge(
                        state: done ? .ok : plant.state,
                        detail: done ? "Regada ahora" : plant.detail,
                        compact: true
                    )
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation(DS.Motion.quick) {
                        if done { watered.remove(plant.id) } else { watered.insert(plant.id) }
                        undoVisible = !done
                    }
                } label: {
                    Image(systemName: done ? "checkmark" : "drop.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(done ? .white : DS.Color.brand)
                        .background(
                            Circle().fill(done ? DS.Color.brand : DS.Color.brandSoft)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(done ? "Deshacer riego de \(plant.name)" : "Regar \(plant.name)")
                .sensoryFeedback(.success, trigger: done)
            }
        }
    }

    // MARK: - Undo (H3: control y libertad)

    private var undoToast: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: "drop.fill").foregroundStyle(DS.Color.brand)
            Text("Riego registrado").font(DS.Text.detail)
            Spacer()
            Button("Deshacer") {
                withAnimation(DS.Motion.quick) {
                    watered.removeAll()
                    undoVisible = false
                }
            }
            .font(DS.Text.detail.weight(.semibold))
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .dsGlass(in: RoundedRectangle(cornerRadius: DS.Radius.card))
        .padding(.horizontal, DS.Space.md)
        .padding(.bottom, DS.Space.md)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview("Hoy, claro") { M01_TodayMockup() }
#Preview("Hoy, oscuro") { M01_TodayMockup().preferredColorScheme(.dark) }
#endif
