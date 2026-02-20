import SwiftUI

/// TeePals V3 Spacing System
/// Simplified spacing scale: 8, 12, 16, 24
enum AppSpacingV3 {

    // MARK: - Base Spacing Units

    /// Extra small - 8pt
    static let xs: CGFloat = 8

    /// Small - 12pt
    static let sm: CGFloat = 12

    /// Medium - 16pt
    static let md: CGFloat = 16

    /// Large - 24pt
    static let lg: CGFloat = 24

    // MARK: - Semantic Spacing

    /// Content horizontal padding - 24pt (px-6 in HTML)
    static let contentPadding: CGFloat = 24

    /// Section spacing - 32pt (space-y-8 in HTML)
    static let sectionSpacing: CGFloat = 32

    /// Card spacing - 16pt (space-y-4 in HTML)
    static let cardSpacing: CGFloat = 16

    /// Small gap - 16pt (gap-4 in HTML)
    static let gapSmall: CGFloat = 16

    /// Tiny gap - 8pt (gap-2 in HTML)
    static let gapTiny: CGFloat = 8

    // MARK: - Corner Radius

    /// Small radius - 12pt
    static let radiusSmall: CGFloat = 12

    /// Medium radius - 16pt
    static let radiusMedium: CGFloat = 16

    /// Large radius - 24pt (rounded-3xl in HTML)
    static let radiusLarge: CGFloat = 24

    /// Button radius - 12pt (rounded-xl in HTML)
    static let radiusButton: CGFloat = 12

    /// Full radius - pill shape
    static let radiusFull: CGFloat = 9999

    // MARK: - Header Padding

    /// Header top padding - 56pt (pt-14 in HTML)
    static let headerTop: CGFloat = 56

    /// Header bottom padding - 16pt (pb-4 in HTML)
    static let headerBottom: CGFloat = 16

    // MARK: - Text Tracking (Letter Spacing)

    /// Wide tracking for uppercase labels - 0.2em
    static let trackingWide: CGFloat = 0.2

    /// Extra wide tracking - 0.15em (for buttons)
    static let trackingExtraWide: CGFloat = 0.15
}

// MARK: - View Extensions

extension View {
    /// Apply standard content horizontal padding (V3)
    func contentPaddingV3() -> some View {
        self.padding(.horizontal, AppSpacingV3.contentPadding)
    }

    /// Apply section spacing (V3)
    func sectionSpacingV3() -> some View {
        self.padding(.vertical, AppSpacingV3.sectionSpacing)
    }
}
