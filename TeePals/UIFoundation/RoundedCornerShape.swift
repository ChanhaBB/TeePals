import SwiftUI
import UIKit

// MARK: - Rounded Corner Shape

/// A custom Shape that allows rounding specific corners (using UIRectCorner).
/// Useful for creating cards with selective corner rounding.
struct RoundedCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
