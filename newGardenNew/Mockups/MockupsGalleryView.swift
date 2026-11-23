#if DEBUG
import SwiftUI

/// Índice de todas las pantallas propuestas para el rediseño.
///
/// Estas vistas son MOCKUPS: no tocan SwiftData, no llaman a ninguna API y no
/// comparten código con la app real. Existen para verse y criticarse antes de
/// escribir la funcionalidad. Están dentro de `#if DEBUG` y no viajan a producción.
///
/// Cada maqueta se presenta a PANTALLA COMPLETA, nunca anidada, para que no se
/// mezcle la barra de pestañas de la app actual con las pantallas propuestas.
struct MockupsGalleryView: View {

    struct Item: Identifiable {
        let id = UUID()
        let code: String
        let title: String
        let subtitle: String
        let symbol: String
        let isNew: Bool
        let destination: AnyView
    }

    @State private var presented: Item?

    private let fullApp = Item(
        code: "APP", title: "Ver la app entera",
        subtitle: "Las 4 pestañas nuevas funcionando juntas",
        symbol: "iphone.gen3", isNew: false,
        destination: AnyView(MockupsFullAppPreview())
    )

    private let navigation: [Item] = [
        Item(code: "M01", title: "Hoy", subtitle: "Reemplaza la lista alfabética como pantalla de entrada",
             symbol: "sun.max.fill", isNew: false, destination: AnyView(M01_TodayMockup())),
        Item(code: "M02", title: "Plantas", subtitle: "La biblioteca, con la foto como protagonista",
             symbol: "square.grid.2x2.fill", isNew: false, destination: AnyView(M02_LibraryMockup())),
        Item(code: "M09", title: "Salud", subtitle: "Sale de dentro de Análisis y pasa a pestaña propia",
             symbol: "stethoscope", isNew: false, destination: AnyView(M09_HealthMockup())),
        Item(code: "M10", title: "Ajustes", subtitle: "De 10 secciones a 4, sin claves obligatorias",
             symbol: "gearshape.fill", isNew: false, destination: AnyView(M10_SettingsMockup())),
    ]

    private let plant: [Item] = [
        Item(code: "M03", title: "Ficha de planta", subtitle: "Un solo scroll, foto grande, IA auditable",
             symbol: "leaf.fill", isNew: false, destination: AnyView(M03_PlantDetailMockup())),
        Item(code: "M04", title: "Chat con la planta", subtitle: "La IA responde con las fuentes reales de ESTA planta",
             symbol: "bubble.left.and.text.bubble.right.fill", isNew: true, destination: AnyView(M04_PlantChatMockup())),
    ]

    private let adding: [Item] = [
        Item(code: "M05", title: "Cámara", subtitle: "Paso 1 de 2: identifica mientras encuadras",
             symbol: "camera.fill", isNew: false, destination: AnyView(M05_AddCameraMockup())),
        Item(code: "M06", title: "Confirmar", subtitle: "Paso 2 de 2: especie y ubicación, nada más",
             symbol: "checkmark.circle.fill", isNew: false, destination: AnyView(M06_AddConfirmMockup())),
        Item(code: "M07", title: "Planta no reconocida", subtitle: "Perfil de cuidado sin saber la especie",
             symbol: "questionmark.circle.fill", isNew: true, destination: AnyView(M07_AddManualMockup())),
        Item(code: "M08", title: "Sembrar semillas", subtitle: "Riego por etapas: germinación, plántula, trasplante",
             symbol: "circle.grid.cross.fill", isNew: true, destination: AnyView(M08_AddSeedMockup())),
    ]

    private let platform: [Item] = [
        Item(code: "M11", title: "Widgets", subtitle: "Regar desde la pantalla de inicio, sin abrir la app",
             symbol: "square.grid.2x2.fill", isNew: true, destination: AnyView(M11_WidgetMockup())),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(fullApp, highlighted: true)
                } header: {
                    Text("Empieza por aquí")
                } footer: {
                    Text("Es lo más parecido a usar la app rediseñada: verás la barra de pestañas nueva (Hoy · Plantas · Salud · Ajustes).")
                }

                section("Las 4 pestañas, una a una", navigation)
                section("Ficha de planta", plant)
                section("Añadir plantas", adding)
                section("Fuera de la app", platform)

                Section {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Label("Esta pestaña no es parte del diseño", systemImage: "wrench.and.screwdriver.fill")
                            .font(DS.Text.detail.weight(.semibold))
                        Text("«Rediseño» es un andamio temporal para revisar las maquetas. Se compila solo en Debug y se borra al implementar. La barra de abajo que ves ahora (Plants · Analysis · Settings) es la app ACTUAL, todavía sin tocar.")
                            .font(DS.Text.caption)
                            .foregroundStyle(.secondary)
                        Text("Las maquetas no guardan nada, no llaman a ninguna API y no comparten código con la app real.")
                            .font(DS.Text.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Rediseño")
            .fullScreenCover(item: $presented) { item in
                ZStack(alignment: .bottomLeading) {
                    item.destination

                    Button { presented = nil } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text(item.code)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Space.sm)
                        .frame(height: 34)
                    }
                    .dsGlass(in: Capsule())
                    .padding(.leading, DS.Space.md)
                    .padding(.bottom, 74)
                    .accessibilityLabel("Cerrar la maqueta \(item.title)")
                }
            }
        }
    }

    private func section(_ title: String, _ items: [Item]) -> some View {
        Section(title) {
            ForEach(items) { row($0) }
        }
    }

    private func row(_ item: Item, highlighted: Bool = false) -> some View {
        Button {
            presented = item
        } label: {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: item.symbol)
                    .font(highlighted ? .title2 : .title3)
                    .foregroundStyle(item.isNew ? DS.Color.aiAccent : DS.Color.brand)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: DS.Space.xxs) {
                        Text(item.title)
                            .font(highlighted ? DS.Text.body.weight(.semibold) : DS.Text.body.weight(.medium))
                        if item.isNew {
                            Text("NUEVO")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(DS.Color.aiAccent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(item.subtitle)
                        .font(DS.Text.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !highlighted {
                    Text(item.code)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Image(systemName: "arrow.up.forward.square.fill")
                    .foregroundStyle(highlighted ? AnyShapeStyle(DS.Color.brand) : AnyShapeStyle(.tertiary))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Las 4 pestañas propuestas, juntas, para ver la navegación completa.
struct MockupsFullAppPreview: View {
    var body: some View {
        TabView {
            M01_TodayMockup()
                .tabItem { Label("Hoy", systemImage: "sun.max.fill") }
            M02_LibraryMockup()
                .tabItem { Label("Plantas", systemImage: "camera.macro") }
            M09_HealthMockup()
                .tabItem { Label("Salud", systemImage: "stethoscope") }
            M10_SettingsMockup()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .tint(DS.Color.brand)
    }
}

#Preview("Galería") { MockupsGalleryView() }
#Preview("App entera") { MockupsFullAppPreview() }
#endif
