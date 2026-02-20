import SwiftUI

/// Individual poster component for onboarding carousel.
/// Just the background image - gradient overlay is applied externally for smooth transitions.
struct OnboardingPosterView: View {
    let imageName: String

    var body: some View {
        // Raw background image only
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped() // Prevent overflow/bleed
            .drawingGroup() // Force GPU rendering for smoother compositing
            .ignoresSafeArea()
    }
}
