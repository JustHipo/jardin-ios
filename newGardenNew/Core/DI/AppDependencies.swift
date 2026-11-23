import Foundation
import SwiftData
import Observation

/// The single place services get constructed and wired together. ViewModels RECEIVE these
/// through the environment; they never instantiate a service themselves — that was the gap
/// in the old `DependencyContainer`, which only injected 3 things while every ViewModel
/// built its own `PlantNetService`/`KeychainService` inline, reading the Keychain directly
/// at the call site. See docs/REPORTE_ESTADO_Y_REDISENO.md section 4.1.
@MainActor
@Observable
final class AppDependencies {
    let keychain: any KeychainServiceProtocol
    let settings: AppSettings
    let locationService: LocationService
    let aiRouter: AIRouter
    let weatherCache: WeatherCache
    let weatherProvider: any WeatherProviding
    let et0ReferenceProvider: any ET0ReferenceProviding
    let plantNetService: any PlantNetServiceProtocol
    private(set) var trefleService: (any TrefleServiceProtocol)?

    init(modelContext: ModelContext, keychain: any KeychainServiceProtocol) {
        self.keychain = keychain
        self.settings = AppSettings(repository: UserSettingsRepository(modelContext: modelContext))
        self.locationService = LocationService(settings: settings)
        self.aiRouter = AIRouter(keychain: keychain)
        self.weatherCache = WeatherCache()
        // TEMPORARY: WeatherKit is the designed provider, but its capability isn't enabled on
        // the App ID yet (pending item 2). Swap back to `WeatherKitProvider()` once it is —
        // see the comment on `Secrets.weatherAPIComKeyTemporary` above.
        self.weatherProvider = WeatherAPIProvider(apiKey: Secrets.weatherAPIComKeyTemporary)
        // Free and keyless, so unlike everything else in this initializer it needs no secret
        // and no pending item to unblock it — see OpenMeteoET0Provider's doc comment.
        self.et0ReferenceProvider = OpenMeteoET0Provider()

        // PlantNet's key ships embedded under its non-profit plan — see
        // docs/ANALISIS_IMPLEMENTACION.md section 7, pending item 3 (The owner still needs to
        // supply the actual key). Placeholder until then.
        self.plantNetService = PlantNetService(apiKey: Secrets.plantNetAPIKey)

        if let trefleToken = try? keychain.read(key: KeychainKey.trefleAPIToken), !trefleToken.isEmpty {
            self.trefleService = TrefleService(token: trefleToken)
        }
    }

    func makeOrchestrator(modelContext: ModelContext) -> WateringOrchestrator {
        WateringOrchestrator(
            plantNetService: plantNetService,
            weatherProvider: weatherProvider,
            et0ReferenceProvider: et0ReferenceProvider,
            weatherCache: weatherCache,
            trefleService: trefleService,
            aiRouter: aiRouter,
            modelContext: modelContext,
            settings: settings
        )
    }

    func refreshTrefleToken() {
        if let token = try? keychain.read(key: KeychainKey.trefleAPIToken), !token.isEmpty {
            trefleService = TrefleService(token: token)
        } else {
            trefleService = nil
        }
    }
}

// `Secrets` vive en Secrets.swift, que no se sube al repo (ver Secrets.swift.example).
