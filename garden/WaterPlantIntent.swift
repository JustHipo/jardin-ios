import AppIntents
import SwiftData
import WidgetKit

/// "Toca la gota para registrar el riego" (M11 mockup) — runs entirely inside the widget's
/// own process, against the SAME store the app uses (see `WidgetModelContainer`), so this is
/// a real `WateringEvent`, not a placeholder the app has to reconcile later. The same intent
/// is what "Oye Siri, riega la Monstera" would call, once exposed via an `AppShortcutsProvider`.
struct WaterPlantIntent: AppIntent {
    static var title: LocalizedStringResource = "Regar planta"
    static var description = IntentDescription("Registra un riego para esta planta.")

    @Parameter(title: "Planta")
    var plantId: String

    init() {}

    init(plantId: String) {
        self.plantId = plantId
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: plantId) else { return .result() }

        let context = ModelContext(WidgetModelContainer.shared)
        let descriptor = FetchDescriptor<Plant>(predicate: #Predicate<Plant> { $0.id == uuid })
        guard let plant = try context.fetch(descriptor).first else { return .result() }

        context.insert(WateringEvent(source: "widget", plant: plant))
        try context.save()

        WidgetCenter.shared.reloadTimelines(ofKind: GardenWidgetKind.identifier)
        return .result()
    }
}
