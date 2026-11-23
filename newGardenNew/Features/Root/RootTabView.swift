import SwiftUI

/// Hoy · Plantas · Salud · Registro · Ajustes. "Registro" is the odd one out relative to P2's
/// original intention-first four tabs: it's a KPI dashboard over the watering algorithm's own
/// audit trail (which engine answered, how each plant's calibration moved, how our ET0
/// compares to Open-Meteo), added to actually answer "¿cómo vamos a ver si mejoró?" instead of
/// requiring anyone to read `os.Logger` output by hand. See docs/BASELINE_ALGORITMO_RIEGO.md.
struct RootTabView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppSettings.self) private var settings
    @State private var showFirstLaunch = false

    var body: some View {
        TabView {
            Tab(String(localized: "tab.today", defaultValue: "Hoy"), systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab(String(localized: "tab.plants", defaultValue: "Plantas"), systemImage: "leaf.fill") {
                LibraryView()
            }
            Tab(String(localized: "tab.health", defaultValue: "Salud"), systemImage: "heart.text.square.fill") {
                HealthView()
            }
            Tab(String(localized: "tab.dashboard", defaultValue: "Registro"), systemImage: "chart.bar.doc.horizontal.fill") {
                DashboardView()
            }
            Tab(String(localized: "tab.settings", defaultValue: "Ajustes"), systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .sheet(isPresented: $showFirstLaunch) {
            FirstLaunchView()
                .interactiveDismissDisabled()
        }
        .task {
            if !settings.hasCompletedFirstLaunch {
                showFirstLaunch = true
            }
        }
    }
}
