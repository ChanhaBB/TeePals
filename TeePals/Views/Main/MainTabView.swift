import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            RoundsView(
                nearbyViewModel: container.makeRoundsListViewModel(),
                activityViewModel: container.makeActivityRoundsViewModel(),
                followingViewModel: container.makeFollowingRoundsViewModel()
            )
                .tabItem {
                    Label("Rounds", systemImage: "figure.golf")
                }
                .tag(1)
            
            NotificationsView(viewModel: container.makeNotificationsViewModel())
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }
                .badge(container.notificationsViewModel?.unreadCount ?? 0)
                .tag(2)
            
            ProfileView(viewModel: container.makeProfileViewModel())
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
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
            profileEditView: {
                AnyView(
                    PhotoEditSheet(
                        viewModel: container.makeProfileEditViewModel(),
                        onSave: {
                            Task {
                                await container.profileGateCoordinator.profileEditDismissed()
                            }
                        }
                    )
                )
            }
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
    MainTabView()
        .environmentObject(AuthService())
        .environmentObject(AppContainer())
        .environmentObject(DeepLinkCoordinator())
}
