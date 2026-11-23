import SwiftUI

/// M10. Structurally matches `Mockups/Screens/M10_SettingsMockup.swift`. Pet safety is a
/// hard requirement, not a nice-to-have — see `PetSafetyVerdict` and the audit finding A1
/// this fixes (pet safety used to depend on an untyped `UserDefaults` string key).
struct SettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppSettings.self) private var settings
    @State private var viewModel: SettingsViewModel?
    @State private var advancedAIExpanded = false
    @State private var trefleExpanded = false

    var body: some View {
        NavigationStack {
            Form {
                if let viewModel {
                    aiSection(viewModel)
                }
                petsSection
                notificationsSection
                locationSection
                if let viewModel {
                    advancedAISection(viewModel)
                    trefleSection(viewModel)
                }
                aboutSection
            }
            .navigationTitle(String(localized: "tab.settings", defaultValue: "Ajustes"))
            .task {
                if viewModel == nil, let dependencies {
                    viewModel = SettingsViewModel(
                        keychain: dependencies.keychain,
                        aiRouter: dependencies.aiRouter,
                        onTrefleTokenChanged: { dependencies.refreshTrefleToken() }
                    )
                }
            }
        }
    }

    /// The three-variant message: never send an ineligible device to a system setting that
    /// does not exist for it.
    @ViewBuilder
    private func aiSection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "cpu.fill").font(.title3).foregroundStyle(DS.Color.brand).frame(width: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "settings.ai.title", defaultValue: "IA en tu iPhone")).font(DS.Text.body.weight(.medium))
                    Text(aiStatusDetail(viewModel)).font(DS.Text.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: viewModel.aiAvailability == .available ? "checkmark.circle.fill" : "info.circle.fill")
                    .foregroundStyle(viewModel.aiAvailability == .available ? DS.Color.statusOK : DS.Color.statusSoon)
            }
            .padding(.vertical, 2)
        }
    }

    private func aiStatusDetail(_ viewModel: SettingsViewModel) -> String {
        switch viewModel.aiAvailability {
        case .available:
            String(localized: "settings.ai.available", defaultValue: "Activa, gratis y sin conexión. No hay nada que configurar.")
        default:
            viewModel.aiAvailability.settingsMessage
        }
    }

    private var petsSection: some View {
        @Bindable var s = settings
        return Section(String(localized: "settings.pets", defaultValue: "Mascotas")) {
            Toggle(String(localized: "settings.pets.toggle", defaultValue: "Tengo mascotas en casa"), isOn: $s.hasPets)
            if settings.hasPets {
                Picker(String(localized: "settings.pets.which", defaultValue: "Cuál"), selection: Binding(
                    get: { settings.petType ?? .dog },
                    set: { settings.petType = $0 }
                )) {
                    Text(String(localized: "settings.pets.dog", defaultValue: "Perro")).tag(PetType.dog)
                    Text(String(localized: "settings.pets.cat", defaultValue: "Gato")).tag(PetType.cat)
                    Text(String(localized: "settings.pets.both", defaultValue: "Ambos")).tag(PetType.both)
                }
            }
        }
    }

    private var notificationsSection: some View {
        @Bindable var s = settings
        return Section(String(localized: "settings.notifications", defaultValue: "Avisos")) {
            Toggle(String(localized: "settings.notifications.toggle", defaultValue: "Avisarme cuando toque regar"), isOn: $s.notificationsEnabled)
                .onChange(of: settings.notificationsEnabled) { _, enabled in
                    if enabled {
                        Task {
                            _ = await NotificationScheduler.requestPermission()
                            NotificationScheduler.scheduleDailyDigest(hour: settings.dailyDigestHour)
                        }
                    } else {
                        NotificationScheduler.cancelDailyDigest()
                    }
                }
            if settings.notificationsEnabled {
                Stepper(value: $s.dailyDigestHour, in: 6...22) {
                    HStack {
                        Text(String(localized: "settings.notifications.hour", defaultValue: "Hora preferida"))
                        Spacer()
                        Text(String(format: "%02d:00", settings.dailyDigestHour)).foregroundStyle(.secondary)
                    }
                }
                .onChange(of: settings.dailyDigestHour) { _, hour in
                    NotificationScheduler.scheduleDailyDigest(hour: hour)
                }
            }
        }
    }

    private var locationSection: some View {
        Section(String(localized: "settings.location", defaultValue: "Ubicación")) {
            HStack {
                Label(settings.cityName ?? String(localized: "settings.location.none", defaultValue: "Sin ubicación"), systemImage: "location.fill")
                Spacer()
                Button(String(localized: "settings.location.change", defaultValue: "Cambiar")) {
                    dependencies?.locationService.requestPermission()
                    dependencies?.locationService.detectLocation()
                }
                .font(DS.Text.detail)
            }
            Text(String(localized: "settings.location.detail", defaultValue: "Se usa para el clima, que ajusta el riego. Nunca sale del dispositivo."))
                .font(DS.Text.caption).foregroundStyle(.secondary)
        }
    }

    private func advancedAISection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            DisclosureGroup(String(localized: "settings.advancedAI", defaultValue: "IA avanzada (opcional)"), isExpanded: $advancedAIExpanded) {
                Text(String(localized: "settings.advancedAI.detail", defaultValue: "La IA del iPhone cubre el análisis de riego y las preguntas sobre tus plantas. Si quieres además un modelo grande, puedes poner tu propia clave."))
                    .font(DS.Text.caption).foregroundStyle(.secondary)

                if viewModel.hasUserKey {
                    HStack {
                        Label(String(localized: "settings.advancedAI.configured", defaultValue: "Clave configurada"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DS.Color.statusOK)
                        Spacer()
                        Button(String(localized: "settings.advancedAI.remove", defaultValue: "Quitar")) { viewModel.removeUserKey() }
                    }
                } else {
                    SecureField(String(localized: "settings.advancedAI.placeholder", defaultValue: "Clave de Claude u OpenAI"), text: Bindable(viewModel).userAPIKeyDraft)
                    Button(String(localized: "settings.advancedAI.save", defaultValue: "Guardar")) { viewModel.saveUserKey() }
                }
                Text(String(localized: "settings.advancedAI.keychainNote", defaultValue: "Se guarda en el Llavero y solo se usa si tú la pones."))
                    .font(DS.Text.caption).foregroundStyle(.tertiary)
            }
        }
    }

    /// The field the design called optional-with-graceful-degradation but that never got a
    /// place to type the token into. `TrefleService` already knew how to read it from the
    /// Keychain; only the Settings side was missing.
    private func trefleSection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            DisclosureGroup(String(localized: "settings.trefle", defaultValue: "Precisión botánica (opcional)"), isExpanded: $trefleExpanded) {
                Text(String(localized: "settings.trefle.detail", defaultValue: "Sin esto la app funciona igual, con menos detalle botánico (tolerancia a sequía, humedad de sustrato). Trefle es gratis para uso personal."))
                    .font(DS.Text.caption).foregroundStyle(.secondary)

                if viewModel.hasTrefleToken {
                    HStack {
                        Label(String(localized: "settings.trefle.configured", defaultValue: "Token configurado"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DS.Color.statusOK)
                        Spacer()
                        Button(String(localized: "settings.trefle.remove", defaultValue: "Quitar")) { viewModel.removeTrefleToken() }
                    }
                } else {
                    SecureField(String(localized: "settings.trefle.placeholder", defaultValue: "Token de Trefle"), text: Bindable(viewModel).trefleTokenDraft)
                    Button(String(localized: "settings.trefle.save", defaultValue: "Guardar")) { viewModel.saveTrefleToken() }
                }
                Text(String(localized: "settings.trefle.keychainNote", defaultValue: "Se guarda en el Llavero. Consíguelo gratis en trefle.io."))
                    .font(DS.Text.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink(String(localized: "settings.tutorial", defaultValue: "Ver el tutorial")) {
                Text(String(localized: "settings.tutorial.placeholder", defaultValue: "Tutorial"))
            }
            HStack {
                Text(String(localized: "settings.version", defaultValue: "Versión"))
                Spacer()
                Text("2.0").foregroundStyle(.secondary)
            }
        } footer: {
            // "Clima de Apple Weather" until WeatherKit's capability is enabled on the App ID
            // (see AppDependencies.weatherProvider) — attributing the wrong provider while
            // WeatherAPI.com is the one actually answering requests would be misleading.
            Text(String(localized: "settings.attribution", defaultValue: "Identificación de especies con Pl@ntNet. Datos botánicos de Trefle. Clima de WeatherAPI.com."))
        }
    }
}
