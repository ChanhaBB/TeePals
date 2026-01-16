import SwiftUI

/// TeePals typography system.
/// Clean, friendly, and readable.
enum AppTypography {
    
    // MARK: - Display (Hero text)
    
    /// Large hero text - 34pt bold
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    
    /// Medium hero text - 28pt bold
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    
    /// Small hero text - 24pt semibold
    static let displaySmall = Font.system(size: 24, weight: .semibold, design: .rounded)
    
    // MARK: - Headlines
    
    /// Large headline - 22pt semibold
    static let headlineLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
    
    /// Medium headline - 18pt semibold
    static let headlineMedium = Font.system(size: 18, weight: .semibold, design: .rounded)
    
    /// Small headline - 16pt semibold
    static let headlineSmall = Font.system(size: 16, weight: .semibold, design: .rounded)
    
    // MARK: - Body
    
    /// Large body - 17pt regular
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    
    /// Medium body - 15pt regular (default)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    
    /// Small body - 14pt regular
    static let bodySmall = Font.system(size: 14, weight: .regular)
    
    // MARK: - Labels
    
    /// Large label - 15pt medium
    static let labelLarge = Font.system(size: 15, weight: .medium)
    
    /// Medium label - 13pt medium
    static let labelMedium = Font.system(size: 13, weight: .medium)
    
    /// Small label - 11pt medium
    static let labelSmall = Font.system(size: 11, weight: .medium)
    
    // MARK: - Captions
    
    /// Caption - 12pt regular
    static let caption = Font.system(size: 12, weight: .regular)
    
    /// Caption emphasis - 12pt medium
    static let captionEmphasis = Font.system(size: 12, weight: .medium)
    
    // MARK: - Button Text
    
    /// Primary button text - 17pt semibold
    static let buttonLarge = Font.system(size: 17, weight: .semibold, design: .rounded)
    
    /// Secondary button text - 15pt medium
    static let buttonMedium = Font.system(size: 15, weight: .medium, design: .rounded)
    
    /// Small button text - 14pt medium
    static let buttonSmall = Font.system(size: 14, weight: .medium, design: .rounded)
}

// MARK: - Text Style Modifiers

extension View {
    /// Apply display large style
    func displayLargeStyle() -> some View {
        font(AppTypography.displayLarge)
    }
    
    /// Apply headline style
    func headlineStyle() -> some View {
        font(AppTypography.headlineMedium)
    }
    
    /// Apply body style
    func bodyStyle() -> some View {
        font(AppTypography.bodyMedium)
    }
    
    /// Apply caption style
    func captionStyle() -> some View {
        font(AppTypography.caption)
            .foregroundColor(AppColors.textSecondary)
    }
}

