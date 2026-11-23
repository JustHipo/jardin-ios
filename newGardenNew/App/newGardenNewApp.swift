import SwiftUI
import os
import SwiftData

@main
struct newGardenNewApp: App {
    var sharedModelContainer: ModelContainer = {
        // Stored in the App Group container, not the app's own sandbox, so `gardenExtension`
        // (the widget, a separate process) can open the exact same file — see
        // Shared/PersistenceConfig.swift. The widget opens it with `cloudKitDatabase: .none`;
        // only the app itself runs the CloudKit mirroring.
        let cloudSchema = Schema(GardenSchema.models)
        let cloudConfig = ModelConfiguration(
            "CloudKit",
            schema: cloudSchema,
            url: GardenSchema.storeURL,
            cloudKitDatabase: .private(CloudKitConfig.containerIdentifier)
        )

        let localSchema = Schema([UserSettings.self])
        let localConfig = ModelConfiguration("Local", schema: localSchema, cloudKitDatabase: .none)

        let fullSchema = Schema(GardenSchema.models + [UserSettings.self])

        do {
            return try ModelContainer(for: fullSchema, configurations: cloudConfig, localConfig)
        } catch {
            AppLog.persistence.fault("Could not create ModelContainer: \(error, privacy: .public)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var dependencies: AppDependencies?

    var body: some Scene {
        WindowGroup {
            RootView(sharedModelContainer: sharedModelContainer, dependencies: $dependencies)
        }
        .modelContainer(sharedModelContainer)
    }
}
