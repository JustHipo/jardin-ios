#if DEBUG
import SwiftUI

/// NUEVO: Chat por planta. La IA no responde desde su conocimiento general:
/// responde sobre ESTA planta, con el contexto que la app ya tiene recopilado
/// (PlantNet, Trefle, clima, historial de riego, fotos, y lo que escribió el
/// usuario). El panel de contexto de arriba hace ese anclaje visible y auditable.
struct M04_PlantChatMockup: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contextExpanded = false
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contextPanel

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        ForEach(MockData.chat) { message in
                            bubble(message)
                        }
                        groundingNote
                    }
                    .padding(DS.Space.md)
                }
                .background(DS.Color.surfaceSunken)
                .scrollContentBackground(.hidden)

                suggestions
                inputBar
            }
            .navigationTitle("Monstera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    // MARK: - Qué sabe la IA (el anclaje, visible)

    private var contextPanel: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DS.Motion.quick) { contextExpanded.toggle() }
            } label: {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DS.Color.brand)
                    Text("Respondiendo con 6 fuentes sobre tu planta")
                        .font(DS.Text.detail.weight(.medium))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: contextExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, DS.Space.sm)
            }
            .buttonStyle(.plain)

            if contextExpanded {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    contextRow("leaf.fill", "PlantNet", "Monstera deliciosa identificada al 94%")
                    contextRow("book.fill", "Trefle", "Luz 7/10 · humedad sustrato 5/10 · tolerancia a sequía 4/10 · tóxica")
                    contextRow("cloud.sun.fill", "WeatherKit", "Santiago: 3 días de historial, hoy y 3 de pronóstico")
                    contextRow("clock.fill", "Tu historial", "6 riegos en 30 días, media de 5 días entre riegos")
                    contextRow("photo.stack.fill", "Tus fotos", "5 fotos desde marzo, la última hace 2 días")
                    contextRow("pencil", "Lo que escribiste", "Living, luz indirecta · maceta 18 cm · tierra universal")

                    Text("Si preguntas algo que no está en estas fuentes, te lo dice en vez de inventarlo.")
                        .font(DS.Text.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DS.Space.xxs)
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
        }
        .background(DS.Color.surface)
    }

    private func contextRow(_ symbol: String, _ source: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Space.xs) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Color.brand)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(source).font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Burbujas

    @ViewBuilder
    private func bubble(_ message: MockData.ChatMessage) -> some View {
        if message.fromUser {
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(DS.Text.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Space.sm)
                    .padding(.vertical, DS.Space.xs + 2)
                    .background(DS.Color.brand, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
            }
        } else {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(message.text)
                    .font(DS.Text.body)
                    .padding(DS.Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.inner)
                            .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
                    )

                if !message.sources.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.xs) {
                            ForEach(message.sources, id: \.0) { source, value in
                                DSSourceChip(source: source, value: value)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 32)
        }
    }

    private var groundingNote: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "lock.fill").font(.system(size: 10))
            Text("Esta conversación se procesa en tu iPhone. No sale de aquí.")
                .font(DS.Text.caption)
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Space.xs)
    }

    // MARK: - Preguntas sugeridas

    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.xs) {
                ForEach(MockData.suggestedQuestions, id: \.self) { question in
                    Button { draft = question } label: {
                        Text(question)
                            .font(DS.Text.caption.weight(.medium))
                            .frame(minHeight: 34)
                            .padding(.horizontal, DS.Space.sm)
                            .foregroundStyle(DS.Color.aiAccent)
                            .background(DS.Color.aiSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.xs)
        }
        .background(DS.Color.surfaceSunken)
    }

    private var inputBar: some View {
        HStack(spacing: DS.Space.xs) {
            TextField("Pregunta sobre tu Monstera", text: $draft, axis: .vertical)
                .font(DS.Text.body)
                .lineLimit(1...4)
                .padding(.horizontal, DS.Space.sm)
                .padding(.vertical, DS.Space.xs + 2)
                .background(DS.Color.surfaceSunken, in: Capsule())

            Button { draft = "" } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(draft.isEmpty ? DS.Color.statusUnknown : DS.Color.brand))
            }
            .buttonStyle(.plain)
            .disabled(draft.isEmpty)
            .accessibilityLabel("Enviar pregunta")
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xs)
        .background(DS.Color.surface)
    }
}

#Preview("Chat, claro") { M04_PlantChatMockup() }
#Preview("Chat, oscuro") { M04_PlantChatMockup().preferredColorScheme(.dark) }
#endif
