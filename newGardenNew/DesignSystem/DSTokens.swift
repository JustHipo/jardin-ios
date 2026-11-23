import SwiftUI

/// Design system tokens.
///
/// Replaces the scattered magic numbers and hardcoded hex colors of the current
/// codebase. Every spacing, radius, color and text style used by the redesigned
/// screens comes from here, so the whole look of the app can be changed from one file.
enum DS {

    // MARK: - Spacing (4pt scale)

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radius (concentric: inner = outer - padding)

    enum Radius {
        static let card: CGFloat = 20
        static let inner: CGFloat = 12
        static let chip: CGFloat = 10
        static let thumb: CGFloat = 14
    }

    // MARK: - Colors (from Assets.xcassets/DS, adapt to light/dark + increased contrast)

    enum Color {
        static let brand = SwiftUI.Color("DS/brand")
        static let brandSoft = SwiftUI.Color("DS/brandSoft")
        static let statusOK = SwiftUI.Color("DS/statusOK")
        static let statusSoon = SwiftUI.Color("DS/statusSoon")
        static let statusOverdue = SwiftUI.Color("DS/statusOverdue")
        static let statusUnknown = SwiftUI.Color("DS/statusUnknown")
        static let aiAccent = SwiftUI.Color("DS/aiAccent")
        static let aiSoft = SwiftUI.Color("DS/aiSoft")
        static let surface = SwiftUI.Color("DS/surface")
        static let surfaceSunken = SwiftUI.Color("DS/surfaceSunken")
        static let hairline = SwiftUI.Color("DS/hairline")
    }

    // MARK: - Typography (5 roles only, all backed by Dynamic Type)

    enum Text {
        static let screenTitle = Font.largeTitle.bold()
        static let sectionTitle = Font.title3.weight(.semibold)
        static let cardTitle = Font.headline
        static let body = Font.body
        static let detail = Font.subheadline
        static let caption = Font.caption
    }

    // MARK: - Motion

    enum Motion {
        static let quick = Animation.spring(response: 0.28, dampingFraction: 0.82)
        static let settle = Animation.spring(response: 0.45, dampingFraction: 0.85)
    }
}

// MARK: - Watering status, presented on three channels at once

/// The current app encodes watering state as color only, which is invisible to
/// VoiceOver and indistinguishable for red/green color blindness. This type
/// carries color **plus** an icon **plus** text for every state.
enum DSWateringState: CaseIterable {
    case ok, soon, overdue, unknown

    var tint: Color {
        switch self {
        case .ok: DS.Color.statusOK
        case .soon: DS.Color.statusSoon
        case .overdue: DS.Color.statusOverdue
        case .unknown: DS.Color.statusUnknown
        }
    }

    var symbol: String {
        switch self {
        case .ok: "checkmark.circle.fill"
        case .soon: "clock.fill"
        case .overdue: "exclamationmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .ok: "Al día"
        case .soon: "Pronto"
        case .overdue: "Con retraso"
        case .unknown: "Sin registro"
        }
    }
}

// MARK: - Glass helper

extension View {
    /// Applies Liquid Glass on iOS 26+, falls back to a material on older systems.
    /// Only for the navigation layer: floating controls and bars, never content.
    @ViewBuilder
    func dsGlass(in shape: some Shape = Capsule()) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}
