#if DEBUG
import SwiftUI

/// P8: Paso 1 de 2. La app abre en la cámara y la identificación arranca sola
/// mientras el usuario encuadra. Hoy hay que pasar por un formulario de contexto
/// y un selector de fototeca antes de ver el primer resultado.
struct M05_AddCameraMockup: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recognized = false
    @State private var route: AddRoute?

    /// Las tres salidas del paso 1: confirmar la especie, anadirla a mano
    /// porque no se reconocio, o declarar que se esta sembrando.
    enum AddRoute: String, Identifiable {
        case confirm, manual, seed
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                viewfinder

                VStack {
                    liveResult
                    Spacer()
                    controls
                }
                .padding(DS.Space.md)
            }
            .navigationTitle("Añadir planta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Elegir de la fototeca", systemImage: "photo.on.rectangle") {
                            route = .confirm
                        }
                        Button("No la reconoce, añadir a mano", systemImage: "pencil") {
                            route = .manual
                        }
                        Button("Estoy sembrando semillas", systemImage: "circle.grid.cross") {
                            route = .seed
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(DS.Motion.settle) { recognized = true }
            }
            .fullScreenCover(item: $route) { destination in
                switch destination {
                case .confirm: M06_AddConfirmMockup()
                case .manual: M07_AddManualMockup()
                case .seed: M08_AddSeedMockup()
                }
            }
        }
    }

    private var viewfinder: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.32, saturation: 0.35, brightness: 0.30),
                         Color(hue: 0.28, saturation: 0.45, brightness: 0.14)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Image(systemName: "leaf.fill")
                .font(.system(size: 180, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.14))

            RoundedRectangle(cornerRadius: DS.Radius.card)
                .strokeBorder(.white.opacity(recognized ? 0.9 : 0.35), lineWidth: 2)
                .frame(width: 260, height: 320)
                .animation(DS.Motion.settle, value: recognized)
        }
    }

    private var liveResult: some View {
        Group {
            if recognized {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DS.Color.brand)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Monstera deliciosa").font(DS.Text.cardTitle)
                        Text("PlantNet · 94% de confianza")
                            .font(DS.Text.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
                .dsGlass(in: RoundedRectangle(cornerRadius: DS.Radius.card))
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { route = .confirm }
            } else {
                HStack(spacing: DS.Space.xs) {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("Buscando la especie")
                        .font(DS.Text.detail)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
                .background(.black.opacity(0.35), in: Capsule())
            }
        }
    }

    private var controls: some View {
        VStack(spacing: DS.Space.md) {
            Text(recognized ? "Toca para confirmar" : "Encuadra la planta entera, con la maceta si se puede")
                .font(DS.Text.caption)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Space.lg)

            HStack(spacing: DS.Space.xl) {
                Button { route = .confirm } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("Elegir de la fototeca")

                Button { route = .confirm } label: {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 74, height: 74)
                        .overlay(Circle().fill(.white).frame(width: 60, height: 60))
                }
                .accessibilityLabel("Tomar foto")

                Button { route = .manual } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("No la reconoce")
            }
        }
    }
}

#Preview("Cámara") { M05_AddCameraMockup() }
#endif
