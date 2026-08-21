import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var container: AppContainer
    @State private var showLaunchScreen = true
    @State private var minimumSplashDone = false

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
                    MainTabView(tabBarState: container.tabBarState)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authService.authState)

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
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            minimumSplashDone = true
            dismissSplashIfReady()
        }
        .onChange(of: authService.authState) { _, _ in
            dismissSplashIfReady()
        }
    }

    private func dismissSplashIfReady() {
        guard minimumSplashDone, authService.authState != .loading, showLaunchScreen else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            showLaunchScreen = false
        }
    }
}

struct LoadingView: View {
    var body: some View {
        LaunchScreenView()
    }
}

#Preview {
    let container = AppContainer()
    return RootView()
        .environmentObject(container.authService)
        .environmentObject(container)
}
