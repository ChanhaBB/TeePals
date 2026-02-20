import SwiftUI

/// TeePals V3 Color System
/// Premium, nature-inspired palette matching the V3 design
enum AppColorsV3 {

    // MARK: - Brand Colors

    /// Forest Green - Primary brand color
    static let forestGreen = Color(hex: "0B3D2E")

    /// Emerald Accent - Secondary accent color
    static let emeraldAccent = Color(hex: "155E49")

    // MARK: - Background Colors

    /// Background Neutral - Off-white background
    static let bgNeutral = Color(hex: "FDFDFD")

    /// Surface White - Pure white cards
    static let surfaceWhite = Color(hex: "FFFFFF")

    // MARK: - Text Colors

    /// Text Primary - Near-black for headings and primary content
    static let textPrimary = Color(hex: "121413")

    /// Text Secondary - Gray for secondary text
    static let textSecondary = Color(hex: "6B7280")

    // MARK: - Border Colors

    /// Border Light - Subtle borders
    static let borderLight = Color(hex: "F1F3F2")

    // MARK: - Semantic Colors (using brand colors)

    /// Primary action color
    static let primary = forestGreen

    /// Background color for screens
    static let background = bgNeutral

    /// Surface color for cards
    static let surface = surfaceWhite

    /// Border color
    static let border = borderLight
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
