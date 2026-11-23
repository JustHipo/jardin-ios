import SwiftUI
import UIKit

/// Matches `Assets.xcassets/DS/brand` and `.../statusOverdue` from the app's design system —
/// duplicated as plain values instead of sharing that asset catalog, which belongs to a
/// different bundle than this widget extension.
extension Color {
    init(light: Color, dark: Color) {
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }

    static let gardenBrand = Color(
        light: Color(red: 0x1F / 255, green: 0x7A / 255, blue: 0x4D / 255),
        dark: Color(red: 0x5B / 255, green: 0xD0 / 255, blue: 0x8C / 255)
    )

    static let gardenOverdue = Color(
        light: Color(red: 0xB5 / 255, green: 0x34 / 255, blue: 0x2A / 255),
        dark: Color(red: 0xFF / 255, green: 0x72 / 255, blue: 0x64 / 255)
    )
}
