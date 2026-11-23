import SwiftUI

// MARK: - Card container

/// The single content container of the app. Replaces the eight different
/// `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))`
/// spellings currently scattered across the views.
struct DSCard<Content: View>: View {
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint ?? DS.Color.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
            )
    }
}

// MARK: - Status badge (color + icon + text, never color alone)

struct DSStatusBadge: View {
    let state: DSWateringState
    var detail: String? = nil
    var compact = false

    var body: some View {
        HStack(spacing: DS.Space.xxs) {
            Image(systemName: state.symbol)
                .font(.caption.weight(.semibold))
            Text(detail ?? state.label)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(state.tint)
        .padding(.horizontal, compact ? DS.Space.xs : DS.Space.sm)
        .padding(.vertical, compact ? 4 : 6)
        .background(state.tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado de riego: \(detail ?? state.label)")
    }
}

// MARK: - Plant thumbnail

/// Stand-in for the user's real photo. Deterministic gradient per plant so the
/// gallery looks intentional rather than broken while there are no real images.
struct DSPlantThumb: View {
    let name: String
    let symbol: String
    var size: CGFloat = 56
    var corner: CGFloat = DS.Radius.thumb

    /// Hash estable. `String.hashValue` usa una semilla aleatoria por proceso, asi que
    /// cambiaria de color en cada arranque.
    private var hue: Double {
        let seed = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 100_003 }
        return Double(seed % 1000) / 1000.0 * 0.35 + 0.18
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.42, brightness: 0.78),
                        Color(hue: hue + 0.06, saturation: 0.55, brightness: 0.52)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Buttons

struct DSPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = DS.Color.brand
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .buttonBorderShape(.roundedRectangle(radius: DS.Radius.inner))
    }
}

struct DSSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .buttonBorderShape(.roundedRectangle(radius: DS.Radius.inner))
    }
}

// MARK: - Source chip (where a piece of data actually came from)

/// Makes the AI auditable. Every generated statement can point at the service
/// and the confidence behind it, instead of appearing as an unattributed claim.
struct DSSourceChip: View {
    let source: String
    var value: String? = nil
    var symbol: String = "checkmark.seal.fill"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            Text(source).font(.system(size: 11, weight: .semibold))
            if let value {
                Text(value)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Space.xs)
        .padding(.vertical, 5)
        .background(DS.Color.surfaceSunken, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip)
                .strokeBorder(DS.Color.hairline, lineWidth: 0.5)
        )
    }
}

// MARK: - Section header

struct DSSectionHeader: View {
    let title: String
    var count: Int? = nil
    var accessory: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(DS.Text.sectionTitle)
            if let count {
                Text("\(count)")
                    .font(DS.Text.detail)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let accessory {
                Text(accessory)
                    .font(DS.Text.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Confidence, in human language

struct DSConfidenceRow: View {
    enum Level { case high, medium, low

        var label: String {
            switch self {
            case .high: "Bastante seguro"
            case .medium: "Con dudas, conviene revisarlo"
            case .low: "No estoy seguro, decide tú"
            }
        }
        var filled: Int {
            switch self {
            case .high: 3
            case .medium: 2
            case .low: 1
            }
        }
        var tint: Color {
            switch self {
            case .high: DS.Color.statusOK
            case .medium: DS.Color.statusSoon
            case .low: DS.Color.statusOverdue
            }
        }
    }

    let level: Level

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i < level.filled ? level.tint : DS.Color.hairline)
                        .frame(width: 14, height: 4)
                }
            }
            Text(level.label)
                .font(DS.Text.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Confianza de la IA: \(level.label)")
    }
}
