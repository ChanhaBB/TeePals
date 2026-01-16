import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var container: AppContainer
    @State private var showLaunchScreen = true
    
    var body: some View {
        ZStack {
            Group {
                switch authService.authState {
                case .loading:
                    LoadingView()
                case .unauthenticated:
                    AuthView()
                case .needsProfile:
                    Tier1OnboardingFlow(viewModel: container.makeTier1OnboardingViewModel())
                case .authenticated:
                    MainTabView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authService.authState)
            
            // Splash screen overlay (minimum 4 seconds)
            if showLaunchScreen {
                LaunchScreenView()
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
                    .zIndex(1)
            }
        }
        .task {
            // Show splash for at least 4 seconds
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(.easeInOut(duration: 0.6)) {
                showLaunchScreen = false
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        LaunchScreenView()
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
        .environmentObject(AppContainer())
}
