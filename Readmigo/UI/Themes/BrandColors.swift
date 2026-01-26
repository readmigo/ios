import SwiftUI
import UIKit

// MARK: - UIColor Hex Extension
extension UIColor {
    convenience init(hex: String) {
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
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - Dynamic Color Helper
private func dynamicColor(light: String, dark: String) -> Color {
    Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(hex: dark)
            : UIColor(hex: light)
    })
}

private func dynamicColor(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? dark : light
    })
}

extension Color {
    // MARK: - Brand Gradient Colors (Primary Gradient)
    /// Blue - start of gradient
    static var brandGradientStart: Color {
        dynamicColor(light: "8BB9FF", dark: "7AABFF")
    }
    /// Purple - middle of gradient
    static var brandGradientMiddle: Color {
        dynamicColor(light: "B9B3F5", dark: "A8A2E6")
    }
    /// Pink - end of gradient
    static var brandGradientEnd: Color {
        dynamicColor(light: "F6B6E8", dark: "E5A5D7")
    }

    // MARK: - Primary Brand Color
    /// Main brand color for buttons, selected states, emphasis
    static var brandPrimary: Color {
        dynamicColor(light: "7C8DF5", dark: "8B9BFF")
    }

    // MARK: - Accent Colors
    /// Accent Purple
    static var accentPurple: Color {
        dynamicColor(light: "9A8CF2", dark: "ABA0FF")
    }
    /// Accent Pink
    static var accentPink: Color {
        dynamicColor(light: "F3A6DC", dark: "FF9ED4")
    }
    /// Accent Blue
    static var accentBlue: Color {
        dynamicColor(light: "A5C7FF", dark: "8DB8FF")
    }
    /// Achievement Gold
    static var achievementGold: Color {
        dynamicColor(light: "FFD36A", dark: "FFCC4D")
    }

    // MARK: - Text Colors
    /// Primary text color
    static var textPrimary: Color {
        dynamicColor(light: "2D2E4A", dark: "F5F5F7")
    }
    /// Secondary text color
    static var textSecondary: Color {
        dynamicColor(light: "6B6F9C", dark: "A1A1A6")
    }
    /// Hint text color
    static var textHint: Color {
        dynamicColor(light: "A3A6C8", dark: "636366")
    }
    /// Text on dark background (stays white in both modes)
    static let textOnDark = Color.white

    // MARK: - Background Colors
    /// Light background - uses system background in dark mode
    static var backgroundLight: Color {
        dynamicColor(light: UIColor(hex: "F7F8FD"), dark: .systemBackground)
    }
    /// Card background - uses secondary system background in dark mode
    static var backgroundCard: Color {
        dynamicColor(light: .white, dark: .secondarySystemBackground)
    }
    /// Subtle background - uses tertiary system background in dark mode
    static var backgroundSubtle: Color {
        dynamicColor(light: UIColor(hex: "EEF0FA"), dark: .tertiarySystemBackground)
    }

    // MARK: - Status Colors (iOS Standard)
    /// Success state
    static var statusSuccess: Color {
        dynamicColor(light: "6ED6A8", dark: "4AD98D")
    }
    /// Warning state
    static var statusWarning: Color {
        dynamicColor(light: "FFC26A", dark: "FFB74D")
    }
    /// Error state
    static var statusError: Color {
        dynamicColor(light: "FF6B6B", dark: "FF5E5E")
    }
    /// Info state
    static var statusInfo: Color {
        dynamicColor(light: "7BAAFF", dark: "6B9AEF")
    }

    // MARK: - Brand Gradient
    static var brandGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [brandGradientStart, brandGradientMiddle, brandGradientEnd]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Legacy Aliases (for compatibility)
    static var brandBlue: Color { brandGradientStart }
    static var brandLavender: Color { brandGradientMiddle }
    static var brandPink: Color { brandGradientEnd }

    // MARK: - Hex Initializer (for static colors only)
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
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
