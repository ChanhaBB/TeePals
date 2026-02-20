import SwiftUI

/// TeePals V3 Shadow System
/// Premium shadow for elevated cards and components
enum AppShadowsV3 {

    // MARK: - Premium Shadow

    /// Premium shadow - subtle elevation with forest green tint
    /// Matches HTML: 0 4px 20px -2px rgba(11, 61, 46, 0.05)
    static let premium = ShadowV3(
        color: Color(red: 11/255, green: 61/255, blue: 46/255).opacity(0.05),
        radius: 10,
        x: 0,
        y: 4
    )

    /// Button shadow - stronger for primary CTAs
    static let button = ShadowV3(
        color: Color.black.opacity(0.15),
        radius: 12,
        x: 0,
        y: 4
    )

    /// Text drop shadow - for text over images
    static let textDrop = ShadowV3(
        color: Color.black.opacity(0.3),
        radius: 3,
        x: 0,
        y: 2
    )
}

// MARK: - Shadow Data Structure

struct ShadowV3 {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    /// Apply premium shadow
    func premiumShadow() -> some View {
        self.shadow(
            color: AppShadowsV3.premium.color,
            radius: AppShadowsV3.premium.radius,
            x: AppShadowsV3.premium.x,
            y: AppShadowsV3.premium.y
        )
    }

    /// Apply button shadow
    func buttonShadowV3() -> some View {
        self.shadow(
            color: AppShadowsV3.button.color,
            radius: AppShadowsV3.button.radius,
            x: AppShadowsV3.button.x,
            y: AppShadowsV3.button.y
        )
    }

    /// Apply text drop shadow
    func textDropShadow() -> some View {
        self.shadow(
            color: AppShadowsV3.textDrop.color,
            radius: AppShadowsV3.textDrop.radius,
            x: AppShadowsV3.textDrop.x,
            y: AppShadowsV3.textDrop.y
        )
    }
}
