#if DEBUG
import SwiftUI

/// Ajustes baja de 10 secciones a 4, porque las claves de API dejan de ser
/// obligatorias. La IA avanzada pasa a ser una sección plegada para quien la quiera.
struct M10_SettingsMockup: View {
    @State private var hasPets = true
    @State private var petType = 1
    @State private var notifications = true
    @State private var advancedAI = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DS.Space.sm) {
                        Image(systemName: "cpu.fill")
                            .font(.title3)
                            .foregroundStyle(DS.Color.brand)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("IA en tu iPhone").font(DS.Text.body.weight(.medium))
                            Text("Activa, gratis y sin conexión. No hay nada que configurar.")
                                .font(DS.Text.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.Color.statusOK)
                    }
                    .padding(.vertical, 2)
                }

                Section("Mascotas") {
                    Toggle("Tengo mascotas en casa", isOn: $hasPets)
                    if hasPets {
                        Picker("Cuál", selection: $petType) {
                            Text("Perro").tag(0)
                            Text("Gato").tag(1)
                            Text("Ambos").tag(2)
                        }
                        Label("3 de tus 8 plantas son tóxicas para gatos", systemImage: "exclamationmark.triangle.fill")
                            .font(DS.Text.caption)
                            .foregroundStyle(DS.Color.statusOverdue)
                    }
                }

                Section("Avisos") {
                    Toggle("Avisarme cuando toque regar", isOn: $notifications)
                    if notifications {
                        HStack {
                            Text("Hora preferida")
                            Spacer()
                            Text("09:00").foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Ubicación") {
                    HStack {
                        Label("Santiago, Chile", systemImage: "location.fill")
                        Spacer()
                        Button("Cambiar") {}.font(DS.Text.detail)
                    }
                    Text("Se usa para el clima, que es lo que ajusta el riego. Nunca sale del dispositivo.")
                        .font(DS.Text.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    DisclosureGroup("IA avanzada (opcional)", isExpanded: $advancedAI) {
                        Text("La IA del iPhone cubre el análisis de riego y las preguntas sobre tus plantas. Si quieres además análisis visual de fotos con un modelo grande, puedes poner tu propia clave.")
                            .font(DS.Text.caption)
                            .foregroundStyle(.secondary)
                        SecureField("Clave de Claude u OpenAI", text: .constant(""))
                        Text("Se guarda en el Llavero y solo se usa si tú la pones.")
                            .font(DS.Text.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Section {
                    Button { } label: { Label("Ver el tutorial", systemImage: "questionmark.circle") }
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text("2.0").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Identificación de especies con Pl@ntNet. Datos botánicos de Trefle.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

#Preview("Ajustes, claro") { M10_SettingsMockup() }
#Preview("Ajustes, oscuro") { M10_SettingsMockup().preferredColorScheme(.dark) }
#endif
