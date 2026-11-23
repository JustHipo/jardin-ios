import Foundation
import os
import SwiftData
import Observation

/// M04: chat anchored to one plant's actual data. Citations are stored as a frozen snapshot
/// on each `ChatMessage` (docs/ANALISIS_IMPLEMENTACION.md section 4) — re-reading a
/// conversation a month later must show what the AI saw that day, not what is true now.
///
/// Degrades rather than disappears when no conversational engine is available: the 6-source
/// panel is static content that exists on any device (PlantNet, Trefle, WeatherKit, the
/// watering history, the photos, what the user wrote) — only the free-form conversation
/// needs a model.
@MainActor
@Observable
final class PlantChatViewModel {
    private let plant: Plant
    private let chatRepository: any ChatMessageRepositoryProtocol
    private let aiRouter: AIRouter
    private let orchestrator: WateringOrchestrator?
    private let modelContext: ModelContext

    private(set) var messages: [ChatMessage] = []
    private(set) var isSending = false
    private(set) var canConverse = false
    private(set) var groundingSummary: [(symbol: String, source: String, detail: String)] = []

    init(plant: Plant, chatRepository: any ChatMessageRepositoryProtocol, aiRouter: AIRouter, orchestrator: WateringOrchestrator?, modelContext: ModelContext) {
        self.plant = plant
        self.chatRepository = chatRepository
        self.aiRouter = aiRouter
        self.orchestrator = orchestrator
        self.modelContext = modelContext
    }

    func load() async {
        messages = (try? chatRepository.fetchForPlant(plant)) ?? []
        buildGroundingSummary()
        canConverse = AIAvailability.current == .available || aiRouter.hasUserProvidedKey
    }

    private func buildGroundingSummary() {
        var rows: [(symbol: String, source: String, detail: String)] = []
        if let species = plant.species {
            rows.append(("leaf.fill", "PlantNet", species))
        }
        let wateringCount = (plant.wateringEvents ?? []).count
        rows.append(("clock.fill", String(localized: "chat.source.history", defaultValue: "Tu historial"),
                      wateringCount == 1 ? "1 riego registrado" : "\(wateringCount) riegos registrados"))
        let photoCount = (plant.photos ?? []).count
        rows.append(("photo.stack.fill", String(localized: "chat.source.photos", defaultValue: "Tus fotos"),
                      photoCount == 1 ? "1 foto" : "\(photoCount) fotos"))
        if let context = plant.userContext, !context.isEmpty {
            rows.append(("pencil", String(localized: "chat.source.written", defaultValue: "Lo que escribiste"), context))
        }
        groundingSummary = rows
    }

    func send(_ text: String) async {
        guard !text.isEmpty else { return }
        AppLog.checkpoint.notice("Chat: send() for plant \(self.plant.id, privacy: .public), canConverse=\(self.canConverse, privacy: .public)")
        let userMessage = ChatMessage(isFromUser: true, text: text, plant: plant)
        modelContext.insert(userMessage)
        messages.append(userMessage)

        guard canConverse else {
            AppLog.checkpoint.notice("Chat: canConverse is false, message stored with no reply attempt")
            return
        }

        isSending = true
        defer { isSending = false }

        // The full context JSON (pot size, location, Trefle data, weather, history) — the
        // same one the watering correction sends, not a thinner summary. Logged in full by
        // `buildContextJSON` itself.
        let grounding = await orchestrator?.buildContextJSON(for: plant)
            ?? groundingSummary.map { "\($0.source): \($0.detail)" }.joined(separator: "\n")

        // Try every candidate engine in priority order, falling through on failure — see
        // `AIRouter.conversationalEngineCandidates`'s doc comment for why: "available" only
        // means the engine looked ready before we asked it to actually generate anything.
        let candidates = await aiRouter.conversationalEngineCandidates()
        AppLog.checkpoint.notice("Chat: \(candidates.count, privacy: .public) candidate engine(s): \(candidates.map { String(describing: $0.1) }.joined(separator: ", "), privacy: .public)")

        for (engine, kind) in candidates {
            do {
                AppLog.checkpoint.notice("Chat: trying \(String(describing: kind), privacy: .public)")
                let reply = try await engine.reply(toUserMessage: text, conversation: messages, groundingContext: grounding)

                let citations = groundingSummary.map { ChatSourceCitation(source: $0.source, value: $0.detail) }
                let assistantMessage = ChatMessage(isFromUser: false, text: reply.text, citations: citations, plant: plant)
                modelContext.insert(assistantMessage)
                messages.append(assistantMessage)

                modelContext.insert(AIAuditEntry(task: .chat, engine: kind, plant: plant))
                try modelContext.save()
                AppLog.checkpoint.notice("Chat: reply from \(String(describing: kind), privacy: .public), \(reply.text.count, privacy: .public) chars")
                return
            } catch {
                AppLog.ai.error("Chat reply failed on \(String(describing: kind), privacy: .public): \(error, privacy: .public)")
                AppLog.checkpoint.notice("Chat: \(String(describing: kind), privacy: .public) FAILED, trying next — \(error, privacy: .public)")
            }
        }

        // Every candidate failed (or there were none).
        AppLog.checkpoint.notice("Chat: all candidates exhausted, showing degraded message")
        let failureMessage = ChatMessage(
            isFromUser: false,
            text: String(localized: "chat.error", defaultValue: "No pude responder ahora. Puedes seguir viendo lo que sé de esta planta arriba."),
            plant: plant
        )
        modelContext.insert(failureMessage)
        messages.append(failureMessage)
    }
}
