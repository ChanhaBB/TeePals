import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeViewV3(
                viewModel: container.makeHomeViewModel(),
                activityViewModel: container.sharedActivityViewModel,
                selectedTab: $selectedTab
            )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
                .environmentObject(container)

            RoundsView(
                nearbyViewModel: container.makeRoundsListViewModel(),
                activityViewModel: container.sharedActivityViewModel
            )
                .tabItem {
                    Label("Rounds", systemImage: "figure.golf")
                }
                .tag(1)

            FeedView(viewModel: container.makeFeedViewModel())
                .tabItem {
                    Label("Feed", systemImage: "newspaper.fill")
                }
                .tag(2)
                .environmentObject(container)

            NotificationsView(viewModel: container.makeNotificationsViewModel())
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }
                .badge(container.notificationsViewModel?.unreadCount ?? 0)
                .tag(3)

            ProfileView(viewModel: container.makeProfileViewModel())
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(AppColors.primary)
        .onAppear {
            // Set global badge color to maroon using UIKit
            UITabBarItem.appearance().badgeColor = UIColor(AppColors.iconAccent)
        }
        .onChange(of: deepLinkCoordinator.pendingDeepLink) { _, newValue in
            // React to new deep links while app is running
            if newValue != nil {
                handlePendingDeepLink()
            }
        }
        .tier2Gated(
            coordinator: container.profileGateCoordinator,
            selectedTab: $selectedTab
        )
        .task {
            // Initialize gate coordinator status on app launch
            await container.profileGateCoordinator.refreshStatus()

            // Preload user profile and notifications on app launch
            // Wrap in Task to defer published updates outside the view cycle
            Task { @MainActor in
                _ = container.makeNotificationsViewModel()
                let profileVM = container.makeProfileViewModel()
                await profileVM.loadProfile()
            }

            // Handle pending deep link (if user just authenticated)
            handlePendingDeepLink()
        }
        .onAppear {
            // Also check on appear (if app was already open)
            handlePendingDeepLink()
        }
    }

    // MARK: - Deep Link Handling

    private func handlePendingDeepLink() {
        guard let deepLink = deepLinkCoordinator.consumePendingDeepLink() else { return }

        // Switch to Rounds tab
        selectedTab = 1

        // Small delay to ensure RoundsView is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Trigger navigation in RoundsView
            deepLinkCoordinator.triggerNavigation(to: deepLink.roundId)
        }
    }
}

#Preview {
    let container = AppContainer()
    return MainTabView()
        .environmentObject(container.authService)
        .environmentObject(container)
        .environmentObject(DeepLinkCoordinator())
}
