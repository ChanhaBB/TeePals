import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @ObservedObject private var tabBarState: TabBarState
    @State private var selectedTab = 0

    init(tabBarState: TabBarState) {
        _tabBarState = ObservedObject(wrappedValue: tabBarState)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // All tabs are created once and kept alive. Opacity + hit-testing
            // controls which is "active". This avoids NavigationStack creation
            // during tab switches (which triggers NavigationRequestObserver warnings).
            ZStack {
                HomeViewV3(
                    viewModel: container.sharedHomeViewModel,
                    activityViewModel: container.sharedActivityViewModel,
                    selectedTab: $selectedTab
                )
                .environmentObject(container)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

                RoundsView(
                    nearbyViewModel: container.sharedRoundsListViewModel,
                    activityViewModel: container.sharedActivityViewModel
                )
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

                FeedPlaceholderView()
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)

                NotificationsView(viewModel: container.sharedNotificationsViewModel)
                    .environmentObject(deepLinkCoordinator)
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)

                ProfileViewV3(viewModel: container.makeProfileViewModel())
                    .opacity(selectedTab == 4 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !tabBarState.isHidden {
                customTabBar
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: deepLinkCoordinator.pendingDeepLink, initial: true) { _, newValue in
            if newValue != nil {
                handlePendingDeepLink()
            }
        }
        .onChange(of: deepLinkCoordinator.activityTabTarget, initial: true) { _, target in
            if target != nil {
                selectedTab = 1
            }
        }
        .onChange(of: deepLinkCoordinator.pendingTabSwitch, initial: true) { _, newTab in
            if let tab = newTab {
                selectedTab = tab
                deepLinkCoordinator.pendingTabSwitch = nil
            }
        }
        .tier2Gated(
            coordinator: container.profileGateCoordinator,
            selectedTab: $selectedTab
        )
        .task {
            // Transfer cold-launch push payload into the coordinator ASAP so
            // the onChange(initial: true) handlers can pick it up.
            if let payload = AppDelegate.coldLaunchPushPayload {
                AppDelegate.coldLaunchPushPayload = nil
                deepLinkCoordinator.handlePushNotificationTap(userInfo: payload)
            }

            // Initialize gate coordinator status on app launch
            await container.profileGateCoordinator.refreshStatus()

            // Preload user profile and notifications on app launch
            Task { @MainActor in
                _ = container.makeNotificationsViewModel()
                let profileVM = container.makeProfileViewModel()
                await profileVM.loadProfile()
            }

            // Handle pending deep link (if user just authenticated via onboarding).
            Task { @MainActor in
                handlePendingDeepLink()
            }
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(AppColorsV3.borderLight)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                Spacer()

                tabButton(
                    index: 0,
                    label: "Home",
                    icon: "house",
                    iconFilled: "house.fill"
                )

                Spacer()

                tabButton(
                    index: 1,
                    label: "Rounds",
                    icon: "figure.golf",
                    iconFilled: "figure.golf"
                )

                Spacer()

                tabButton(
                    index: 2,
                    label: "Feed",
                    icon: "newspaper",
                    iconFilled: "newspaper.fill"
                )

                Spacer()

                tabButton(
                    index: 3,
                    label: "Alerts",
                    icon: "bell",
                    iconFilled: "bell.fill",
                    showBadge: hasUnreadNotifications
                )

                Spacer()

                tabButton(
                    index: 4,
                    label: "Profile",
                    icon: "person",
                    iconFilled: "person.fill"
                )

                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(
            AppColorsV3.surfaceWhite.opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(
        index: Int,
        label: String,
        icon: String,
        iconFilled: String,
        showBadge: Bool = false
    ) -> some View {
        let isActive = selectedTab == index

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isActive ? iconFilled : icon)
                        .font(.system(size: 24))
                        .frame(height: 24)

                    if showBadge {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 6, y: -2)
                    }
                }

                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.025)
            }
            .frame(width: 56)
            .foregroundColor(isActive ? AppColorsV3.forestGreen : AppColorsV3.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var hasUnreadNotifications: Bool {
        (container.notificationsViewModel?.unreadCount ?? 0) > 0
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
    return MainTabView(tabBarState: container.tabBarState)
        .environmentObject(container.authService)
        .environmentObject(container)
        .environmentObject(DeepLinkCoordinator())
}
