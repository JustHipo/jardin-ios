#if DEBUG
import SwiftUI

/// NUEVO: Siembra desde semilla. Una semilla no tiene "ciclo de riego fijo":
/// tiene etapas, y cada etapa quiere un riego distinto. Esto obliga a un cambio
/// en el modelo de datos (una planta pasa a tener `growthStage` y un plan por
/// etapas), no solo a una pantalla nueva.
struct M08_AddSeedMockup: View {
    @Environment(\.dismiss) private var dismiss
    @State private var seed = "Tomate cherry"
    @State private var method = 1
    @State private var sownDate = Date.now
    @State private var currentStage = 1

    private let methods: [(String, String)] = [
        ("Semillero", "square.grid.3x3.fill"),
        ("Maceta", "circle.grid.2x2"),
        ("Directo a tierra", "mountain.2.fill"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header
                    seedField
                    methodField
                    dateField
                    plan
                    differenceNote
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, 100)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                DSPrimaryButton(title: "Crear plan de siembra", systemImage: "checkmark")
                    .padding(.horizontal, DS.Space.md)
                    .padding(.vertical, DS.Space.sm)
                    .background(.bar)
            }
            .navigationTitle("Sembrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
    }

    private var header: some View {
        DSCard(tint: DS.Color.brandSoft) {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: "circle.grid.cross.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.brand)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text("Una semilla no se riega como una planta")
                        .font(DS.Text.cardTitle)
                    Text("Necesita humedad constante para germinar y luego cada vez menos. La app va a cambiar el riego sola según la etapa.")
                        .font(DS.Text.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, DS.Space.xs)
    }

    private var seedField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("¿Qué sembraste?").font(DS.Text.sectionTitle)
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Busca la semilla", text: $seed)
                    .textFieldStyle(.plain)
                    .font(DS.Text.body)
            }
            .padding(DS.Space.sm)
            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.inner)
                    .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.xs) {
                    ForEach(["Tomate cherry", "Albahaca", "Lechuga", "Rúcula", "Zanahoria", "No está en la lista"], id: \.self) { option in
                        Button { seed = option } label: {
                            Text(option)
                                .font(DS.Text.caption.weight(.medium))
                                .frame(minHeight: 34)
                                .padding(.horizontal, DS.Space.sm)
                                .foregroundStyle(seed == option ? .white : DS.Color.brand)
                                .background(seed == option ? DS.Color.brand : DS.Color.brandSoft, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            DSSourceChip(source: "Trefle", value: "Solanum lycopersicum · germina en 6 a 10 días a 20-25°",
                         symbol: "book.fill")
        }
    }

    private var methodField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("¿Dónde?").font(DS.Text.sectionTitle)
            HStack(spacing: DS.Space.xs) {
                ForEach(Array(methods.enumerated()), id: \.offset) { index, item in
                    let isSelected = method == index
                    Button {
                        withAnimation(DS.Motion.quick) { method = index }
                    } label: {
                        VStack(spacing: DS.Space.xs) {
                            Image(systemName: item.1).font(.title3)
                            Text(item.0)
                                .font(DS.Text.caption.weight(.medium))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76)
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
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("¿Cuándo?").font(DS.Text.sectionTitle)
            DatePicker("Fecha de siembra", selection: $sownDate, displayedComponents: .date)
                .font(DS.Text.body)
                .padding(DS.Space.sm)
                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.inner)
                        .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
                )
        }
    }

    // MARK: - El plan por etapas

    private var plan: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            DSSectionHeader(title: "Plan de riego por etapa")

            DSCard {
                VStack(spacing: 0) {
                    ForEach(Array(MockData.seedStages.enumerated()), id: \.offset) { index, stage in
                        stageRow(index: index, stage: stage)
                        if index < MockData.seedStages.count - 1 {
                            connector(done: index < currentStage)
                        }
                    }
                }
            }
        }
    }

    private func stageRow(index: Int, stage: (String, String, String, Bool)) -> some View {
        let isCurrent = index == currentStage
        let isDone = index < currentStage
        return HStack(alignment: .top, spacing: DS.Space.sm) {
            ZStack {
                Circle()
                    .fill(isDone || isCurrent ? DS.Color.brand : DS.Color.hairline)
                    .frame(width: 26, height: 26)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Circle().fill(.white).frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Space.xs) {
                    Text(stage.0)
                        .font(DS.Text.body.weight(isCurrent ? .semibold : .regular))
                    if isCurrent {
                        Text("AHORA")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(DS.Color.brand, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Text(stage.1)
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(stage.2)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .opacity(isDone ? 0.6 : 1)
    }

    private func connector(done: Bool) -> some View {
        HStack(spacing: DS.Space.sm) {
            Rectangle()
                .fill(done ? DS.Color.brand : DS.Color.hairline)
                .frame(width: 2, height: 18)
                .padding(.leading, 12)
            Spacer()
        }
    }

    private var differenceNote: some View {
        DSCard(tint: DS.Color.aiSoft) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "bell.badge.fill").foregroundStyle(DS.Color.aiAccent)
                    Text("Qué va a pasar").font(DS.Text.cardTitle)
                }
                Text("Los primeros 10 días te aviso **dos veces al día** para pulverizar. Cuando detecte por tus fotos que ya germinó, paso solo a riego cada 2 días y te lo digo.")
                    .font(DS.Text.body)
                Text("Si no germina en 14 días, te aviso y revisamos qué pudo fallar.")
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Semillas, claro") { M08_AddSeedMockup() }
#Preview("Semillas, oscuro") { M08_AddSeedMockup().preferredColorScheme(.dark) }
#endif
