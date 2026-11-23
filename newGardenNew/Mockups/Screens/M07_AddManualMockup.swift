#if DEBUG
import SwiftUI

/// NUEVO: Planta no reconocida. Cuando ni PlantNet ni la IA saben qué es, la app
/// no puede dejar al usuario en un callejón sin salida. En vez de pedir la especie,
/// pregunta por lo que el usuario SÍ puede ver, y deduce un perfil de cuidado a
/// partir del grupo funcional (suculenta, tropical, aromática...) en lugar de la especie.
struct M07_AddManualMockup: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = "La del living"
    @State private var group = 1
    @State private var leaf = 0
    @State private var size = 1
    @State private var notes = ""

    private let groups: [(String, String, String)] = [
        ("Suculenta o cactus", "drop.triangle", "Hoja gruesa, aguanta sequía"),
        ("Tropical de interior", "leaf.fill", "Hoja ancha y blanda, quiere humedad"),
        ("Aromática o comestible", "fork.knife", "Albahaca, menta, perejil..."),
        ("Arbusto o exterior", "tree.fill", "Vive fuera todo el año"),
        ("No sabría decir", "questionmark.circle", "La IA propone lo más seguro"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    header

                    field("¿Cómo la llamas?") {
                        TextField("Un nombre para reconocerla", text: $nickname)
                            .textFieldStyle(.plain)
                            .font(DS.Text.body)
                            .padding(DS.Space.sm)
                            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.inner)
                                    .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
                            )
                    }

                    field("¿A qué se parece más?") {
                        VStack(spacing: DS.Space.xs) {
                            ForEach(Array(groups.enumerated()), id: \.offset) { index, item in
                                groupRow(index: index, title: item.0, symbol: item.1, detail: item.2)
                            }
                        }
                    }

                    field("Un par de detalles más") {
                        VStack(spacing: DS.Space.sm) {
                            segmented("Hoja", options: ["Fina", "Ancha", "Con espinas"], selection: $leaf)
                            segmented("Tamaño", options: ["Pequeña", "Mediana", "Grande"], selection: $size)
                        }
                    }

                    field("¿Algo más que sepas?") {
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            TextField("Me la regalaron, florece en primavera, la tengo en el baño...",
                                      text: $notes, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(DS.Text.body)
                                .lineLimit(3...6)
                                .padding(DS.Space.sm)
                                .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.inner)
                                        .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
                                )
                            Text("Cualquier cosa que escribas aquí entra en el contexto de la IA cada vez que analice esta planta.")
                                .font(DS.Text.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    provisionalProfile
                    retryLater
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, 100)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                DSPrimaryButton(title: "Guardar sin especie", systemImage: "checkmark")
                    .padding(.horizontal, DS.Space.md)
                    .padding(.vertical, DS.Space.sm)
                    .background(.bar)
            }
            .navigationTitle("Añadir a mano")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
    }

    private var header: some View {
        DSCard {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.statusSoon)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text("No pude identificar la especie")
                        .font(DS.Text.cardTitle)
                    Text("No pasa nada. Con que me digas a qué se parece, puedo calcular un riego razonable y afinarlo con el tiempo.")
                        .font(DS.Text.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, DS.Space.xs)
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title).font(DS.Text.sectionTitle)
            content()
        }
    }

    private func groupRow(index: Int, title: String, symbol: String, detail: String) -> some View {
        let isSelected = group == index
        return Button {
            withAnimation(DS.Motion.quick) { group = index }
        } label: {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 32)
                    .foregroundStyle(isSelected ? DS.Color.brand : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(DS.Text.body.weight(.medium))
                    Text(detail).font(DS.Text.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DS.Color.brand : DS.Color.hairline)
            }
            .padding(DS.Space.sm)
            .frame(minHeight: 56)
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

    private func segmented(_ title: String, options: [String], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(title).font(DS.Text.caption).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var provisionalProfile: some View {
        DSCard(tint: DS.Color.aiSoft) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "sparkles").foregroundStyle(DS.Color.aiAccent)
                    Text("Perfil provisional").font(DS.Text.cardTitle)
                }
                Text("Tropical de interior, hoja ancha, tamaño mediano: **riego cada 6 días**, luz indirecta, cuidado con el encharcamiento.")
                    .font(DS.Text.body)
                DSConfidenceRow(level: .low)
                Text("Al no saber la especie voy a ser conservador y a ajustar el ciclo con lo que pase de verdad: tus riegos, tus fotos y el clima.")
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var retryLater: some View {
        DSCard {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DS.Color.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Reintentar identificación más adelante")
                        .font(DS.Text.body.weight(.medium))
                    Text("Cuando eche hojas nuevas o florezca, una foto nueva suele bastar.")
                        .font(DS.Text.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: .constant(true)).labelsHidden()
            }
        }
    }
}

#Preview("A mano, claro") { M07_AddManualMockup() }
#Preview("A mano, oscuro") { M07_AddManualMockup().preferredColorScheme(.dark) }
#endif
