import SwiftUI

/// TeePals color palette.
/// Golf-inspired, friendly, and accessible.
enum AppColors {
    
    // MARK: - Brand Colors
    
    /// Primary brand green - fairway green
    static let primary = Color(red: 0.1, green: 0.45, blue: 0.25)
    
    /// Darker shade for pressed states
    static let primaryDark = Color(red: 0.08, green: 0.35, blue: 0.2)
    
    /// Lighter shade for backgrounds
    static let primaryLight = Color(red: 0.1, green: 0.45, blue: 0.25).opacity(0.1)
    
    /// Secondary accent - warm sand/gold
    static let accent = Color(red: 0.85, green: 0.65, blue: 0.3)
    
    /// Accent dark for pressed states
    static let accentDark = Color(red: 0.7, green: 0.5, blue: 0.2)
    
    // MARK: - Icon Colors
    
    /// Icon accent - dark brownish red for location/calendar icons
    static let iconAccent = Color(red: 0.6, green: 0.25, blue: 0.2)
    
    // MARK: - Semantic Colors
    
    /// Success green
    static let success = Color(red: 0.2, green: 0.7, blue: 0.4)
    
    /// Warning amber
    static let warning = Color(red: 0.95, green: 0.6, blue: 0.2)
    
    /// Error red
    static let error = Color(red: 0.9, green: 0.3, blue: 0.25)
    
    /// Info blue
    static let info = Color(red: 0.2, green: 0.5, blue: 0.85)
    
    // MARK: - Text Colors
    
    /// Primary text - high emphasis
    static let textPrimary = Color(.label)
    
    /// Secondary text - medium emphasis
    static let textSecondary = Color(.secondaryLabel)
    
    /// Tertiary text - low emphasis
    static let textTertiary = Color(.tertiaryLabel)
    
    /// Disabled text
    static let textDisabled = Color(.quaternaryLabel)
    
    /// Inverse text (on dark backgrounds)
    static let textInverse = Color.white
    
    // MARK: - Surface Colors
    
    /// Main background
    static let background = Color(.systemBackground)
    
    /// Primary background (alias for main)
    static let backgroundPrimary = Color(.systemBackground)
    
    /// Secondary background
    static let backgroundSecondary = Color(.secondarySystemBackground)
    
    /// Grouped background
    static let backgroundGrouped = Color(.systemGroupedBackground)
    
    /// Card/elevated surface
    static let surface = Color(.systemBackground)
    
    /// Secondary surface
    static let surfaceSecondary = Color(.secondarySystemBackground)
    
    /// Tertiary surface
    static let surfaceTertiary = Color(.tertiarySystemBackground)
    
    // MARK: - State Colors
    
    /// Disabled state background
    static let disabled = Color(.systemGray4)
    
    // MARK: - Border Colors
    
    /// Default border
    static let border = Color(.separator)
    
    /// Strong border (focused states)
    static let borderStrong = Color(.opaqueSeparator)
    
    // MARK: - Gradients
    
    /// Primary gradient for hero elements
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Fairway gradient (subtle green tones)
    static let fairwayGradient = LinearGradient(
        colors: [
            Color(red: 0.15, green: 0.5, blue: 0.3),
            Color(red: 0.08, green: 0.4, blue: 0.22)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Convenience View Extensions

extension View {
    /// Apply primary brand color to foreground
    func primaryForeground() -> some View {
        foregroundColor(AppColors.primary)
    }
    
    /// Apply primary brand color to background
    func primaryBackground() -> some View {
        background(AppColors.primary)
    }
}

