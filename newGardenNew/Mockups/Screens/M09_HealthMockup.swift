#if DEBUG
import SwiftUI

/// El Centro de Salud deja de estar a tres toques dentro de "Análisis" y pasa a
/// ser una pestaña propia, porque responde a una intención muy concreta del
/// usuario: "esto se ve mal, ¿qué le pasa?".
struct M09_HealthMockup: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.md) {
                    diagnoseCTA
                    lastDiagnosis
                    timeline
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.bottom, DS.Space.xxl)
            }
            .background(DS.Color.surfaceSunken)
            .scrollContentBackground(.hidden)
            .navigationTitle("Salud")
        }
    }

    private var diagnoseCTA: some View {
        DSCard {
            VStack(spacing: DS.Space.sm) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(DS.Color.brand)
                    .padding(.top, DS.Space.xs)

                Text("Fotografía la parte que te preocupa")
                    .font(DS.Text.sectionTitle)
                    .multilineTextAlignment(.center)

                Text("Una hoja con manchas, un tallo blando, bichos en el envés. Cuanto más cerca, mejor.")
                    .font(DS.Text.detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                DSPrimaryButton(title: "Diagnosticar", systemImage: "camera.fill")
                    .padding(.top, DS.Space.xxs)

                HStack(spacing: DS.Space.xs) {
                    DSSourceChip(source: "PlantNet", value: "detección de enfermedades", symbol: "leaf.fill")
                    DSSourceChip(source: "On-device", value: "tus fotos no salen", symbol: "lock.fill")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var lastDiagnosis: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.sm) {
                    DSPlantThumb(name: "Monstera", symbol: "leaf.fill", size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monstera").font(DS.Text.cardTitle)
                        Text("Diagnóstico de hace 2 días")
                            .font(DS.Text.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    scoreRing(6)
                }

                Divider()

                ForEach(MockData.healthIssues) { issue in
                    HStack(alignment: .top, spacing: DS.Space.xs) {
                        Image(systemName: issue.severity.symbol)
                            .font(.caption)
                            .foregroundStyle(issue.severity.tint)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(issue.title).font(DS.Text.body.weight(.medium))
                            Text(issue.detail)
                                .font(DS.Text.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text("Qué hacer").font(DS.Text.cardTitle)
                    ForEach(["Espaciar el riego a 8 días durante 3 semanas",
                             "Retirar las 3 hojas amarillas desde la base",
                             "Comprobar que el plato no acumule agua"], id: \.self) { step in
                        HStack(alignment: .top, spacing: DS.Space.xs) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.Color.brand)
                                .padding(.top, 4)
                            Text(step).font(DS.Text.detail)
                        }
                    }
                }
                .padding(.top, DS.Space.xxs)

                HStack(spacing: DS.Space.xs) {
                    DSSourceChip(source: "PlantNet", value: "sin patógeno detectado", symbol: "leaf.fill")
                    DSSourceChip(source: "Tu historial", value: "riego 1,4x sobre lo normal", symbol: "clock.fill")
                }
            }
        }
    }

    private func scoreRing(_ score: Int) -> some View {
        ZStack {
            Circle()
                .stroke(DS.Color.hairline, lineWidth: 5)
            Circle()
                .trim(from: 0, to: Double(score) / 10)
                .stroke(DS.Color.statusSoon, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(score)").font(.title3.bold())
                Text("de 10").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Salud \(score) de 10")
    }

    private var timeline: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSSectionHeader(title: "Evolución", accessory: "Últimos 6 meses")
                HStack(alignment: .bottom, spacing: DS.Space.xs) {
                    ForEach(Array([8, 9, 7, 7, 5, 6].enumerated()), id: \.offset) { index, value in
                        VStack(spacing: DS.Space.xxs) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(value >= 7 ? DS.Color.statusOK : DS.Color.statusSoon)
                                .frame(height: CGFloat(value) * 9)
                            Text(["Abr", "May", "Jun", "Jul", "Ago", "Sep"][index])
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 110, alignment: .bottom)

                Text("Bajó de 9 a 5 entre junio y agosto, coincidiendo con la ola de calor y con que la moviste a la ventana sur.")
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Salud, claro") { M09_HealthMockup() }
#Preview("Salud, oscuro") { M09_HealthMockup().preferredColorScheme(.dark) }
#endif
