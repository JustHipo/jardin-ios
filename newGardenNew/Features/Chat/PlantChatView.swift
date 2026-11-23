import SwiftUI
import SwiftData

/// M04. Structurally matches `Mockups/Screens/M04_PlantChatMockup.swift`. When the device
/// can't converse, this degrades to a data sheet instead of hiding or apologizing (the
/// design agreement's answer to "no ocultar, ni dar una mala noticia").
struct PlantChatView: View {
    let plantId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: PlantChatViewModel?
    @State private var contextExpanded = false
    @State private var draft = ""
    @State private var plantName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let viewModel {
                    contextPanel(viewModel)
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Space.md) {
                            ForEach(viewModel.messages) { message in bubble(message) }
                            groundingNote
                        }
                        .padding(DS.Space.md)
                    }
                    .background(DS.Color.surfaceSunken)
                    .scrollContentBackground(.hidden)

                    if viewModel.canConverse {
                        inputBar(viewModel)
                    } else {
                        degradedNotice
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(plantName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close", defaultValue: "Cerrar")) { dismiss() }
                }
            }
            .task {
                guard viewModel == nil, let dependencies else { return }
                let repo = PlantRepository(modelContext: modelContext)
                guard let plant = try? repo.fetchById(plantId) else { return }
                plantName = plant.name
                viewModel = PlantChatViewModel(
                    plant: plant,
                    chatRepository: ChatMessageRepository(modelContext: modelContext),
                    aiRouter: dependencies.aiRouter,
                    orchestrator: dependencies.makeOrchestrator(modelContext: modelContext),
                    modelContext: modelContext
                )
                await viewModel?.load()
            }
        }
    }

    private func contextPanel(_ viewModel: PlantChatViewModel) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DS.Motion.quick) { contextExpanded.toggle() }
            } label: {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(DS.Color.brand)
                    Text("Respondiendo con \(viewModel.groundingSummary.count) fuentes sobre tu planta")
                        .font(DS.Text.detail.weight(.medium)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: contextExpanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
            }
            .buttonStyle(.plain)

            if contextExpanded {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    ForEach(Array(viewModel.groundingSummary.enumerated()), id: \.offset) { _, row in
                        contextRow(row.symbol, row.source, row.detail)
                    }
                    Text(String(localized: "chat.groundingRule", defaultValue: "Si preguntas algo que no está en estas fuentes, te lo dice en vez de inventarlo."))
                        .font(DS.Text.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, DS.Space.xxs)
                }
                .padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Divider()
        }
        .background(DS.Color.surface)
    }

    private func contextRow(_ symbol: String, _ source: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Space.xs) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(DS.Color.brand).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(source).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        if message.isFromUser {
            HStack {
                Spacer(minLength: 48)
                Text(message.text).font(DS.Text.body).foregroundStyle(.white)
                    .padding(.horizontal, DS.Space.sm).padding(.vertical, DS.Space.xs + 2)
                    .background(DS.Color.brand, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
            }
        } else {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(message.text).font(DS.Text.body).padding(DS.Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(DS.Color.hairline, lineWidth: 0.5))

                if !message.citations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Space.xs) {
                            ForEach(message.citations, id: \.self) { citation in
                                DSSourceChip(source: citation.source, value: citation.value)
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
            Text(String(localized: "chat.privacyNote", defaultValue: "Esta conversación se procesa en tu iPhone. No sale de aquí."))
                .font(DS.Text.caption)
        }
        .foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.top, DS.Space.xs)
    }

    /// The degraded state for devices without Apple Intelligence and without a user key:
    /// the panel above is still fully usable, this just replaces the free-text input.
    private var degradedNotice: some View {
        VStack(spacing: DS.Space.xs) {
            Text(String(localized: "chat.degraded", defaultValue: "Tu iPhone no puede hacer preguntas en lenguaje natural, pero arriba tienes todo lo que sé de esta planta."))
                .font(DS.Text.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            NavigationLink(String(localized: "chat.degraded.settings", defaultValue: "Usar mi propia clave de IA")) {
                SettingsView()
            }
            .font(DS.Text.caption.weight(.semibold))
        }
        .padding(DS.Space.md)
        .background(DS.Color.surface)
    }

    private func inputBar(_ viewModel: PlantChatViewModel) -> some View {
        HStack(spacing: DS.Space.xs) {
            TextField("Pregunta sobre tu \(plantName)", text: $draft, axis: .vertical)
                .font(DS.Text.body).lineLimit(1...4)
                .padding(.horizontal, DS.Space.sm).padding(.vertical, DS.Space.xs + 2)
                .background(DS.Color.surfaceSunken, in: Capsule())

            Button {
                let text = draft
                draft = ""
                Task { await viewModel.send(text) }
            } label: {
                Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(draft.isEmpty ? DS.Color.statusUnknown : DS.Color.brand))
            }
            .buttonStyle(.plain)
            .disabled(draft.isEmpty || viewModel.isSending)
            .accessibilityLabel(String(localized: "chat.send", defaultValue: "Enviar pregunta"))
        }
        .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.xs)
        .background(DS.Color.surface)
    }
}
