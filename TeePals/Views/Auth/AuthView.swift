import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        // Onboarding carousel with 3 posters
        OnboardingCarouselView()
            .environmentObject(authService)
    }
}

#Preview {
    let container = AppContainer()
    return AuthView()
        .environmentObject(container.authService)
}
