#if DEBUG
import SwiftUI

/// Fake but realistic data for the mockup screens. No networking, no persistence.
enum MockData {

    struct Plant: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let species: String
        let symbol: String
        let state: DSWateringState
        let detail: String
        let location: String
        let toxicToPets: Bool
    }

    static let monstera = Plant(
        name: "Monstera", species: "Monstera deliciosa", symbol: "leaf.fill",
        state: .overdue, detail: "2 días de retraso", location: "Living, luz indirecta",
        toxicToPets: true
    )

    static let plants: [Plant] = [
        monstera,
        Plant(name: "Potus", species: "Epipremnum aureum", symbol: "camera.macro",
              state: .overdue, detail: "1 día de retraso", location: "Baño", toxicToPets: true),
        Plant(name: "Ficus", species: "Ficus lyrata", symbol: "tree.fill",
              state: .soon, detail: "Riega hoy", location: "Living, ventana sur", toxicToPets: false),
        Plant(name: "Lavanda", species: "Lavandula angustifolia", symbol: "leaf.circle.fill",
              state: .soon, detail: "En 2 días", location: "Terraza, sol directo", toxicToPets: false),
        Plant(name: "Aloe", species: "Aloe vera", symbol: "drop.triangle.fill",
              state: .ok, detail: "En 6 días", location: "Cocina", toxicToPets: true),
        Plant(name: "Albahaca", species: "Ocimum basilicum", symbol: "leaf.fill",
              state: .ok, detail: "En 3 días", location: "Cocina, ventana", toxicToPets: false),
        Plant(name: "Cactus", species: "Echinopsis oxygona", symbol: "mountain.2.fill",
              state: .ok, detail: "En 12 días", location: "Escritorio", toxicToPets: false),
        Plant(name: "Tomates", species: "Solanum lycopersicum", symbol: "circle.grid.cross.fill",
              state: .unknown, detail: "Recién sembrado", location: "Huerto, cajón 1", toxicToPets: false),
    ]

    static var overdue: [Plant] { plants.filter { $0.state == .overdue } }
    static var soon: [Plant] { plants.filter { $0.state == .soon } }
    static var fine: [Plant] { plants.filter { $0.state == .ok || $0.state == .unknown } }

    // MARK: - Chat

    struct ChatMessage: Identifiable {
        let id = UUID()
        let fromUser: Bool
        let text: String
        let sources: [(String, String?)]
    }

    static let chat: [ChatMessage] = [
        .init(fromUser: true,
              text: "Se le están poniendo las hojas de abajo amarillas. ¿Es por exceso de agua?",
              sources: []),
        .init(fromUser: false,
              text: """
              Con lo que sé de tu planta en concreto, es probable que sí.

              La regaste 6 veces en los últimos 30 días, con una media de 5 días entre riegos. Para una Monstera deliciosa en maceta de 18 cm con tierra universal, Trefle indica una humedad de sustrato objetivo de 5 sobre 10, que es un régimen bastante más seco que ese.

              El amarilleo que empieza por las hojas inferiores y avanza hacia arriba es el patrón típico de raíz encharcada, no de falta de riego (que empieza por los bordes y los deja crispados).
              """,
              sources: [("Tu historial", "6 riegos / 30 días"), ("Trefle", "humedad 5/10"), ("Tus fotos", "5 desde marzo")]),
        .init(fromUser: false,
              text: "Antes de cambiar nada: ¿el plato de abajo queda con agua después de regar?",
              sources: []),
    ]

    static let suggestedQuestions = [
        "¿Cuándo la trasplanto?",
        "¿Es tóxica para mi gato?",
        "¿Por qué las hojas nuevas salen sin agujeros?",
        "¿Le doy fertilizante ahora?",
    ]

    // MARK: - Identification

    struct Suggestion: Identifiable {
        let id = UUID()
        let common: String
        let scientific: String
        let confidence: Int
        let symbol: String
        /// Fotos de referencia que devuelve PlantNet junto al resultado.
        /// Son TODAS del mismo organo que el clasificador detecto en la foto del
        /// usuario, no una mezcla. Verificado contra la API real el 13-09-2026.
        let references: [Reference]
    }

    struct Reference: Identifiable {
        let id = UUID()
        let symbol: String
        let author: String
    }

    /// Organo que PlantNet detecto en la foto del usuario, y su confianza.
    /// Determina de que son TODAS las fotos de referencia que vuelven.
    static let detectedOrgan = (name: "hoja", plural: "Hojas", confidence: 79)

    static let suggestions: [Suggestion] = [
        .init(common: "Monstera", scientific: "Monstera deliciosa", confidence: 94, symbol: "leaf.fill",
              references: [
                .init(symbol: "leaf.fill", author: "m.rousselot"),
                .init(symbol: "leaf", author: "j.tinguely"),
                .init(symbol: "leaf.fill", author: "a.benitez"),
                .init(symbol: "leaf", author: "p.bonnet"),
                .init(symbol: "leaf.fill", author: "s.dufour"),
              ]),
        .init(common: "Monstera adansonii", scientific: "Monstera adansonii", confidence: 3, symbol: "leaf",
              references: [
                .init(symbol: "leaf", author: "p.bonnet"),
                .init(symbol: "leaf.fill", author: "s.dufour"),
                .init(symbol: "leaf", author: "c.mora"),
              ]),
        .init(common: "Filodendro", scientific: "Philodendron bipinnatifidum", confidence: 2, symbol: "leaf",
              references: [
                .init(symbol: "leaf", author: "c.mora"),
                .init(symbol: "leaf.fill", author: "l.perrier"),
                .init(symbol: "leaf", author: "n.garcia"),
                .init(symbol: "leaf.fill", author: "f.torres"),
              ]),
        .init(common: "Costilla de Adán menor", scientific: "Monstera obliqua", confidence: 1, symbol: "leaf",
              references: [
                .init(symbol: "leaf", author: "f.torres"),
                .init(symbol: "leaf.fill", author: "r.silva"),
              ]),
        .init(common: "Potus gigante", scientific: "Epipremnum pinnatum", confidence: 1, symbol: "camera.macro",
              references: [
                .init(symbol: "camera.macro", author: "r.silva"),
                .init(symbol: "leaf", author: "m.kowalski"),
                .init(symbol: "leaf.fill", author: "d.almeida"),
              ]),
        .init(common: "Anturio", scientific: "Anthurium andraeanum", confidence: 1, symbol: "leaf.circle.fill",
              references: [
                .init(symbol: "leaf.circle.fill", author: "d.almeida"),
                .init(symbol: "leaf", author: "a.benitez"),
              ]),
    ]

    // MARK: - Health

    struct HealthIssue: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let severity: DSWateringState
    }

    static let healthIssues: [HealthIssue] = [
        .init(title: "Clorosis en hojas basales",
              detail: "Amarilleo entre nervaduras en las 3 hojas inferiores, compatible con exceso de riego.",
              severity: .overdue),
        .init(title: "Sin señales de plaga",
              detail: "No se detectan ácaros, cochinilla ni telarañas en el envés.",
              severity: .ok),
    ]

    // MARK: - Seeds

    static let seedStages: [(String, String, String, Bool)] = [
        ("Siembra", "Sustrato húmedo constante, sin encharcar", "Días 0 a 3", true),
        ("Germinación", "Riego por pulverización, 2 veces al día", "Días 4 a 10", true),
        ("Plántula", "Riego cada 2 días, primera luz directa suave", "Días 11 a 25", false),
        ("Trasplante", "Pasar a maceta definitiva, riego cada 3 días", "Día 26 en adelante", false),
    ]
}
#endif
