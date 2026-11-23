import SwiftUI
import SwiftData

/// Builds `AppDependencies` once the real `ModelContext` exists, then hands off to the tab
/// structure. This indirection exists because `AppDependencies` needs a `ModelContext` to
/// construct `AppSettings`, and that context is only available once inside the SwiftUI
/// environment, not at `App` init time.
struct RootView: View {
    let sharedModelContainer: ModelContainer
    @Binding var dependencies: AppDependencies?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let dependencies {
                RootTabView()
                    .environment(\.dependencies, dependencies)
                    .environment(dependencies.settings)
            } else {
                Color.clear.onAppear {
                    dependencies = AppDependencies(modelContext: modelContext, keychain: KeychainService())
                }
            }
        }
    }
}
