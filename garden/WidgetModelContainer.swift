import SwiftData

/// Opens the SAME store the app writes to, from the App Group container (see
/// `Shared/PersistenceConfig.swift`). Deliberately `cloudKitDatabase: .none`: only the app
/// itself runs CloudKit mirroring — a second sync engine in the extension process would be
/// redundant and is not the recommended pattern for a widget sharing a SwiftData store.
enum WidgetModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema(GardenSchema.models)
        let configuration = ModelConfiguration(
            "CloudKit",
            schema: schema,
            url: GardenSchema.storeURL,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Widget could not open the shared plant store: \(error)")
        }
    }()
}
