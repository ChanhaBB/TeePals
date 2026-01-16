import SwiftUI

/// TeePals spacing system.
/// Consistent spacing values based on 4pt grid.
enum AppSpacing {
    
    // MARK: - Base Units
    
    /// Extra small - 4pt
    static let xs: CGFloat = 4
    
    /// Small - 8pt
    static let sm: CGFloat = 8
    
    /// Medium - 12pt
    static let md: CGFloat = 12
    
    /// Large - 16pt
    static let lg: CGFloat = 16
    
    /// Extra large - 24pt
    static let xl: CGFloat = 24
    
    /// 2x Extra large - 32pt
    static let xxl: CGFloat = 32
    
    /// 3x Extra large - 48pt
    static let xxxl: CGFloat = 48
    
    // MARK: - Semantic Spacing
    
    /// Content padding (horizontal margins)
    static let contentPadding: CGFloat = 16
    
    /// Card internal padding
    static let cardPadding: CGFloat = 16
    
    /// Section spacing (between major sections)
    static let sectionSpacing: CGFloat = 24
    
    /// Item spacing (between list items)
    static let itemSpacing: CGFloat = 12
    
    /// Inline spacing (between inline elements)
    static let inlineSpacing: CGFloat = 8
    
    /// Icon-to-text spacing
    static let iconSpacing: CGFloat = 8
    
    // MARK: - Corner Radius
    
    /// Small radius - 6pt (badges, tags)
    static let radiusSmall: CGFloat = 6
    
    /// Medium radius - 10pt (buttons, inputs)
    static let radiusMedium: CGFloat = 10
    
    /// Large radius - 14pt (cards)
    static let radiusLarge: CGFloat = 14
    
    /// Extra large radius - 20pt (modals)
    static let radiusXL: CGFloat = 20
    
    /// Full/pill radius
    static let radiusFull: CGFloat = 9999
    
    // MARK: - Button Heights
    
    /// Large button height - 52pt
    static let buttonHeightLarge: CGFloat = 52
    
    /// Medium button height - 44pt
    static let buttonHeightMedium: CGFloat = 44
    
    /// Small button height - 36pt
    static let buttonHeightSmall: CGFloat = 36
    
    // MARK: - Input Heights
    
    /// Standard text field height - 48pt
    static let inputHeight: CGFloat = 48
    
    /// Compact text field height - 40pt
    static let inputHeightCompact: CGFloat = 40
}

// MARK: - AppRadii Alias (for convenience)

/// Corner radius constants (alias for AppSpacing radius values)
enum AppRadii {
    static let card: CGFloat = AppSpacing.radiusLarge
    static let button: CGFloat = AppSpacing.radiusMedium
    static let chip: CGFloat = AppSpacing.radiusSmall
    static let modal: CGFloat = AppSpacing.radiusXL
}

// MARK: - Padding Extensions

extension View {
    /// Apply standard content padding
    func contentPadding() -> some View {
        padding(.horizontal, AppSpacing.contentPadding)
    }
    
    /// Apply card padding
    func cardPadding() -> some View {
        padding(AppSpacing.cardPadding)
    }
    
    /// Apply standard card corner radius
    func cardRadius() -> some View {
        cornerRadius(AppSpacing.radiusLarge)
    }
}

