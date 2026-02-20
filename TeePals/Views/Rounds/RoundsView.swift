import SwiftUI

/// Main Rounds tab view with segmented control: Nearby | Activity
struct RoundsView: View {

    // MARK: - Dependencies

    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject private var nearbyViewModel: RoundsListViewModel
    @StateObject private var activityViewModel: ActivityRoundsViewModelV2

    @State private var selectedSegment: RoundsSegment = .nearby
    @State private var showingCreateRound = false
    @State private var showingFilters = false
    @State private var selectedRound: Round?

    init(
        nearbyViewModel: RoundsListViewModel,
        activityViewModel: ActivityRoundsViewModelV2
    ) {
        _nearbyViewModel = StateObject(wrappedValue: nearbyViewModel)
        _activityViewModel = StateObject(wrappedValue: activityViewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColorsV3.bgNeutral.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header section (segmented control + filter summary)
                    headerSection

                    // Content area per segment
                    segmentContent
                }

                // Floating action button (always visible)
                floatingActionButton
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedRound) { round in
                if let roundId = round.id {
                    RoundDetailView(viewModel: container.makeRoundDetailViewModel(roundId: roundId))
                }
            }
            .sheet(isPresented: $showingCreateRound) {
                CreateRoundFlow(
                    viewModel: container.makeCreateRoundViewModel(),
                    onSuccess: { _ in refreshCurrentSegment() }
                )
            }
            .sheet(isPresented: $showingFilters) {
                RoundsFilterSheet(viewModel: nearbyViewModel)
            }
            .task {
                handlePendingActivityTarget()

                await loadSegment(selectedSegment)

                Task {
                    await preloadOtherSegments()
                }
            }
            .onChange(of: selectedSegment) { _, newSegment in
                Task { await loadSegment(newSegment) }
            }
            .onChange(of: deepLinkCoordinator.navigationTrigger) { _, roundId in
                if let roundId = roundId {
                    handleDeepLinkNavigation(roundId: roundId)
                }
            }
            .onChange(of: deepLinkCoordinator.activityTabTarget) { _, _ in
                handlePendingActivityTarget()
            }
            .animation(.none, value: selectedSegment)
        }
    }
    
    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // iOS-style segmented control
            IOSSegmentedControl(
                items: RoundsSegment.allCases,
                itemTitle: { $0.title },
                selection: $selectedSegment
            )
            .padding(.horizontal, AppSpacingV3.contentPadding)

            // Sub-navigation per segment
            if selectedSegment == .nearby {
                FilterSummaryViewV3(
                    filters: nearbyViewModel.filters,
                    userProfile: nearbyViewModel.userProfile,
                    onTap: { showingFilters = true }
                )
            } else if selectedSegment == .activity {
                ActivityChipBar(
                    selectedTab: $activityViewModel.selectedTab,
                    inviteCount: activityViewModel.inviteCount
                )
                .padding(.horizontal, AppSpacingV3.contentPadding)
            }
        }
        .padding(.top, AppSpacingV3.headerTop)
        .padding(.bottom, selectedSegment == .activity ? AppSpacingV3.xs : 0)
        .background(AppColorsV3.bgNeutral.opacity(0.95))
        .overlay(
            Group {
                if selectedSegment == .nearby {
                    Rectangle()
                        .fill(AppColorsV3.borderLight)
                        .frame(height: 1)
                }
            },
            alignment: .bottom
        )
    }
    
    // MARK: - Segment Content

    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case .nearby:
            NearbyRoundsContent(
                viewModel: nearbyViewModel,
                onRoundTap: { selectedRound = $0 },
                onCreateRound: { attemptCreateRound() },
                onShowFilters: { showingFilters = true }
            )
            .refreshable { await nearbyViewModel.refresh() }

        case .activity:
            ActivityRoundsViewV2(
                viewModel: activityViewModel,
                onRoundTap: { selectedRound = $0 },
                onCreateRound: { attemptCreateRound() },
                onSwitchToNearby: { selectedSegment = .nearby }
            )
            .refreshable { await activityViewModel.refresh() }
        }
    }
    
    // MARK: - Floating Action Button

    private var floatingActionButton: some View {
        Button { attemptCreateRound() } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(AppColorsV3.forestGreen)
                .clipShape(Circle())
                .shadow(color: AppColorsV3.forestGreen.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, AppSpacingV3.contentPadding)
        .padding(.bottom, AppSpacingV3.lg)
    }
    
    // MARK: - Actions
    
    private func attemptCreateRound() {
        Task {
            let canProceed = await container.profileGateCoordinator.requireTier2Async()
            if canProceed { showingCreateRound = true }
        }
    }
    
    private func loadSegment(_ segment: RoundsSegment) async {
        switch segment {
        case .nearby:
            await nearbyViewModel.loadRounds()
        case .activity:
            await activityViewModel.loadActivity()
        }
    }

    private func refreshCurrentSegment() {
        Task {
            switch selectedSegment {
            case .nearby: await nearbyViewModel.refresh()
            case .activity: await activityViewModel.refresh()
            }
        }
    }

    private func preloadOtherSegments() async {
        // Load segments that aren't currently selected in the background
        switch selectedSegment {
        case .nearby:
            // Preload Activity
            await activityViewModel.loadActivity()

        case .activity:
            // Preload Nearby
            await nearbyViewModel.loadRounds()
        }
    }

    // MARK: - Activity Tab Deep Link

    private func handlePendingActivityTarget() {
        if let tab = deepLinkCoordinator.consumeActivityTabTarget() {
            selectedSegment = .activity
            activityViewModel.selectedTab = tab
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLinkNavigation(roundId: String) {
        // Create a minimal Round object to trigger navigation
        let round = Round(
            id: roundId,
            hostUid: "",
            title: "Loading...",
            courseCandidates: [],
            teeTimeCandidates: []
        )

        // Trigger navigation
        selectedRound = round

        // Clear the navigation trigger
        deepLinkCoordinator.clearNavigationTrigger()
    }
}
