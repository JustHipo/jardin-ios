#if DEBUG
import SwiftUI

/// REQUISITO: Widgets. La acción principal de la app (regar) ocurre varias veces
/// por semana y hoy cuesta 3 toques después de abrir la app. El widget la saca
/// fuera: se ve y se completa desde la pantalla de inicio.
///
/// Estas son las caras del widget renderizadas sobre un fondo simulado. La
/// extensión real de WidgetKit se crea en la implementación, no en la maqueta.
struct M11_WidgetMockup: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    intro

                    group("Pantalla de inicio · mediano", detail: "El que resuelve el problema: se riega desde aquí.") {
                        homeScreenBackdrop { mediumWidget }
                    }

                    group("Pantalla de inicio · pequeño", detail: "Para quien solo quiere el número.") {
                        homeScreenBackdrop { HStack { smallWidget; Spacer() } }
                    }

                    group("Pantalla de bloqueo", detail: "Visible sin desbloquear el teléfono.") {
                        lockScreenBackdrop
                    }

                    behaviour
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.xxl)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var intro: some View {
        DSCard(tint: DS.Color.brandSoft) {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text("Por qué es un requisito y no un extra")
                    .font(DS.Text.cardTitle)
                Text("Regar es la acción que el usuario repite. Si para hacerla tiene que abrir la app, buscar la planta y deslizar, la app compite con su memoria y pierde. El widget convierte el recordatorio y la acción en la misma cosa.")
                    .font(DS.Text.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, DS.Space.xs)
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title).font(DS.Text.sectionTitle)
            Text(detail).font(DS.Text.caption).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Fondos simulados

    @ViewBuilder
    private func homeScreenBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.58, saturation: 0.45, brightness: 0.55),
                         Color(hue: 0.72, saturation: 0.50, brightness: 0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            content()
                .padding(DS.Space.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    private var lockScreenBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.62, saturation: 0.35, brightness: 0.22),
                         Color(hue: 0.70, saturation: 0.45, brightness: 0.10)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: DS.Space.xs) {
                Text("lunes 14 de septiembre")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                Text("9:41")
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: DS.Space.md) {
                    lockCircular
                    lockRectangular
                }
                .padding(.top, DS.Space.xxs)
            }
            .padding(.vertical, DS.Space.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }

    // MARK: - Caras del widget

    private var mediumWidget: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack {
                Label("2 plantas con sed", systemImage: "drop.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Color.statusOverdue)
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Color.brand)
            }

            ForEach(MockData.overdue) { plant in
                HStack(spacing: DS.Space.xs) {
                    DSPlantThumb(name: plant.name, symbol: plant.symbol, size: 30, corner: 8)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(plant.name).font(.system(size: 13, weight: .medium))
                        Text(plant.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Color.statusOverdue)
                    }
                    Spacer()
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(DS.Color.brand))
                }
            }

            Text("Toca la gota para registrar el riego")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(DS.Space.sm)
        .frame(height: 158)
        .frame(maxWidth: .infinity)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Image(systemName: "drop.fill")
                .font(.system(size: 15))
                .foregroundStyle(DS.Color.statusOverdue)
            Spacer()
            Text("2")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(DS.Color.statusOverdue)
            Text("con sed")
                .font(.system(size: 13, weight: .medium))
            Text("Monstera, Potus")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 158, height: 158, alignment: .leading)
        .padding(DS.Space.sm)
        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private var lockCircular: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.35), lineWidth: 4)
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Image(systemName: "drop.fill").font(.system(size: 11))
                Text("2").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
    }

    private var lockRectangular: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "drop.fill").font(.system(size: 14))
            VStack(alignment: .leading, spacing: -1) {
                Text("2 con sed").font(.system(size: 14, weight: .semibold))
                Text("Monstera y Potus").font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Space.sm)
        .frame(height: 62)
    }

    // MARK: - Comportamiento

    private var behaviour: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text("Cómo se comporta").font(DS.Text.cardTitle)
                ForEach([
                    ("hand.tap.fill", "El toque en la gota registra el riego sin abrir la app", "App Intent interactivo, disponible desde iOS 17"),
                    ("arrow.clockwise", "Se refresca al regar desde la app y al terminar el análisis diario", "WidgetCenter.reloadTimelines"),
                    ("mic.fill", "\"Oye Siri, riega la Monstera\" funciona con el mismo intent", "AppIntent compartido con Atajos"),
                    ("moon.zzz.fill", "Si no hay nada pendiente, muestra la siguiente planta y cuándo toca", "Nunca queda vacío"),
                ], id: \.0) { symbol, title, detail in
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        Image(systemName: symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Color.brand)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title).font(DS.Text.detail)
                            Text(detail)
                                .font(DS.Text.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

#Preview("Widgets, claro") { M11_WidgetMockup() }
#Preview("Widgets, oscuro") { M11_WidgetMockup().preferredColorScheme(.dark) }
#endif
