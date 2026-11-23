import Foundation
import SwiftData

/// One message in a per-plant chat (M04). Sources are stored as a SNAPSHOT of their value at
/// the time, never as a live reference — the design session was explicit that a citation
/// re-read a month later must show what the AI saw that day, not what is true now, or the
/// citations would quietly start lying. See docs/ANALISIS_IMPLEMENTACION.md section 4.
@Model
final class ChatMessage {
    var id: UUID = UUID()
    var sentAt: Date = Date.now
    var isFromUser: Bool = true
    var text: String = ""

    /// JSON-encoded [ChatSourceCitation], a frozen snapshot of what was cited when this
    /// message was generated. Empty for user messages.
    var citationsJSON: String?

    var plant: Plant?

    init(
        id: UUID = UUID(),
        sentAt: Date = .now,
        isFromUser: Bool,
        text: String,
        citations: [ChatSourceCitation] = [],
        plant: Plant? = nil
    ) {
        self.id = id
        self.sentAt = sentAt
        self.isFromUser = isFromUser
        self.text = text
        self.citationsJSON = Self.encode(citations)
        self.plant = plant
    }

    var citations: [ChatSourceCitation] {
        get {
            guard let json = citationsJSON, let data = json.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([ChatSourceCitation].self, from: data)) ?? []
        }
        set { citationsJSON = Self.encode(newValue) }
    }

    private static func encode(_ values: [ChatSourceCitation]) -> String? {
        guard let data = try? JSONEncoder().encode(values) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// A frozen snapshot of one cited source, e.g. ("WeatherKit", "32° · 0 mm"). Codable so it
/// can be stored inline as JSON — it has no independent identity worth a relationship.
struct ChatSourceCitation: Codable, Sendable, Hashable {
    let source: String
    let value: String?
}
