import SwiftUI

/// M07: when neither PlantNet nor the AI can identify the species, the app doesn't leave the
/// user stuck. It asks what they CAN see and derives care from the functional group instead
/// of the species — a succulent waters like a succulent whether or not you know if it's an
/// Echeveria or a Haworthia. This is also what feeds `WateringRuleEngine`'s crop coefficient.
struct AddPlantUnrecognizedView: View {
    @Bindable var viewModel: AddPlantViewModel
    var onFinished: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                header

                field(String(localized: "addPlant.unrecognized.nickname", defaultValue: "¿Cómo la llamas?")) {
                    TextField(String(localized: "addPlant.unrecognized.nicknamePlaceholder", defaultValue: "Un nombre para reconocerla"), text: $viewModel.nickname)
                        .textFieldStyle(.plain).font(DS.Text.body).padding(DS.Space.sm)
                        .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(DS.Color.hairline, lineWidth: 0.5))
                }

                field(String(localized: "addPlant.unrecognized.looksLike", defaultValue: "¿A qué se parece más?")) {
                    VStack(spacing: DS.Space.xs) {
                        ForEach(FunctionalGroup.allCases, id: \.self) { group in
                            groupRow(group)
                        }
                    }
                }

                field(String(localized: "addPlant.unrecognized.moreDetails", defaultValue: "¿Algo más que sepas?")) {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        TextField(String(localized: "addPlant.unrecognized.notesPlaceholder", defaultValue: "Me la regalaron, florece en primavera..."), text: $viewModel.freeNotes, axis: .vertical)
                            .textFieldStyle(.plain).font(DS.Text.body).lineLimit(3...6).padding(DS.Space.sm)
                            .background(DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(DS.Color.hairline, lineWidth: 0.5))
                    }
                }

                provisionalProfile
                retryLater
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, 100)
        }
        .background(DS.Color.surfaceSunken)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            DSPrimaryButton(title: String(localized: "addPlant.unrecognized.save", defaultValue: "Guardar sin especie"), systemImage: "checkmark") {
                viewModel.saveUnrecognized()
                onFinished()
            }
            .padding(.horizontal, DS.Space.md).padding(.vertical, DS.Space.sm)
            .background(.bar)
        }
        .navigationTitle(String(localized: "addPlant.unrecognized.title", defaultValue: "Añadir a mano"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        DSCard {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Image(systemName: "questionmark.circle.fill").font(.title3).foregroundStyle(DS.Color.statusSoon)
                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(String(localized: "addPlant.unrecognized.headerTitle", defaultValue: "No pude identificar la especie")).font(DS.Text.cardTitle)
                    Text(String(localized: "addPlant.unrecognized.headerDetail", defaultValue: "No pasa nada. Con que me digas a qué se parece, puedo calcular un riego razonable."))
                        .font(DS.Text.detail).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, DS.Space.xs)
    }

    @ViewBuilder
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title).font(DS.Text.sectionTitle)
            content()
        }
    }

    private func groupRow(_ group: FunctionalGroup) -> some View {
        let isSelected = viewModel.functionalGroup == group
        return Button {
            withAnimation(DS.Motion.quick) { viewModel.functionalGroup = group }
        } label: {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: group.symbol).font(.title3).frame(width: 32).foregroundStyle(isSelected ? DS.Color.brand : .secondary)
                Text(group.label).font(DS.Text.body.weight(.medium))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").foregroundStyle(isSelected ? DS.Color.brand : DS.Color.hairline)
            }
            .padding(DS.Space.sm)
            .frame(minHeight: 56)
            .background(isSelected ? DS.Color.brandSoft : DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.inner))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.inner).strokeBorder(isSelected ? DS.Color.brand : DS.Color.hairline, lineWidth: isSelected ? 2 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private var provisionalProfile: some View {
        DSCard(tint: DS.Color.aiSoft) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "sparkles").foregroundStyle(DS.Color.aiAccent)
                    Text(String(localized: "addPlant.unrecognized.provisionalTitle", defaultValue: "Perfil provisional")).font(DS.Text.cardTitle)
                }
                Text(viewModel.functionalGroup.label + ": " + String(localized: "addPlant.unrecognized.provisionalDetail", defaultValue: "voy a ser conservador y a ajustar el riego con lo que pase de verdad."))
                    .font(DS.Text.body)
                DSConfidenceRow(level: .low)
            }
        }
    }

    private var retryLater: some View {
        DSCard {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "arrow.clockwise.circle.fill").font(.title3).foregroundStyle(DS.Color.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "addPlant.unrecognized.retryTitle", defaultValue: "Reintentar identificación más adelante")).font(DS.Text.body.weight(.medium))
                    Text(String(localized: "addPlant.unrecognized.retryDetail", defaultValue: "Cuando eche hojas nuevas, una foto nueva suele bastar.")).font(DS.Text.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $viewModel.retryLaterEnabled).labelsHidden()
            }
        }
    }
}
