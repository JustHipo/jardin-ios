import SwiftUI

/// No Sign in with Apple, no mandatory tutorial. CloudKit syncs with the device's iCloud
/// account already — a sign-in screen would be a wall before any value, with nothing behind
/// it (decision 5, docs/ANALISIS_IMPLEMENTACION.md section 4: in the old app, signing in only
/// wrote a name and email to UserDefaults, it never touched sync). This screen just gets out
/// of the way and drops the user straight into adding their first plant.
struct FirstLaunchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var showAddPlant = false

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Space.lg) {
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(DS.Color.brand)
                Text(String(localized: "firstLaunch.title", defaultValue: "Bienvenido a tu jardín"))
                    .font(DS.Text.screenTitle)
                    .multilineTextAlignment(.center)
                Text(String(localized: "firstLaunch.subtitle", defaultValue: "Sin claves que configurar. Empieza fotografiando tu primera planta."))
                    .font(DS.Text.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.xl)
                Spacer()
                DSPrimaryButton(title: String(localized: "firstLaunch.cta", defaultValue: "Añadir mi primera planta"), systemImage: "camera.fill") {
                    finish()
                    showAddPlant = true
                }
                .padding(.horizontal, DS.Space.lg)
                Button(String(localized: "firstLaunch.skip", defaultValue: "Ahora no")) {
                    finish()
                }
                .font(DS.Text.detail)
                .padding(.bottom, DS.Space.lg)
            }
            .background(DS.Color.surfaceSunken)
            .sheet(isPresented: $showAddPlant, onDismiss: { dismiss() }) {
                AddPlantCameraView()
            }
        }
    }

    private func finish() {
        settings.hasCompletedFirstLaunch = true
        if !showAddPlant { dismiss() }
    }
}
