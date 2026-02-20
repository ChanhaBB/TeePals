import SwiftUI

/// TeePals V3 Gradient System
/// Card overlay gradients for hero images
enum AppGradientsV3 {

    // MARK: - Card Gradients

    /// Hero card gradient - forest green tinted overlay for rounds with course photos
    /// Matches HTML: linear-gradient(180deg, rgba(11,61,46,0) 0%, rgba(11,61,46,0.3) 50%, rgba(11,61,46,0.85) 100%)
    static let heroCardForestGreen = LinearGradient(
        stops: [
            .init(color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0), location: 0),
            .init(color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0.3), location: 0.5),
            .init(color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0.85), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Empty state card gradient - black overlay for empty/no round state
    /// Matches HTML: linear-gradient(180deg, rgba(0,0,0,0) 40%, rgba(0,0,0,0.6) 80%, rgba(0,0,0,0.8) 100%)
    static let heroCardEmpty = LinearGradient(
        stops: [
            .init(color: Color.black.opacity(0), location: 0.4),
            .init(color: Color.black.opacity(0.6), location: 0.8),
            .init(color: Color.black.opacity(0.8), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Generic dark overlay - for general use
    static let darkOverlay = LinearGradient(
        stops: [
            .init(color: Color.black.opacity(0), location: 0),
            .init(color: Color.black.opacity(0.6), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Extensions

extension View {
    /// Apply hero card forest green gradient overlay
    func heroCardGradient() -> some View {
        self.overlay(AppGradientsV3.heroCardForestGreen)
    }

    /// Apply empty state card gradient overlay
    func emptyCardGradient() -> some View {
        self.overlay(AppGradientsV3.heroCardEmpty)
    }
}
