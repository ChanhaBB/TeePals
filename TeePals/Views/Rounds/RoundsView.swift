import SwiftUI

/// Main Rounds tab view with segmented control: Nearby | Activity | Following
struct RoundsView: View {
    
    // MARK: - Dependencies

    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @StateObject private var nearbyViewModel: RoundsListViewModel
    @StateObject private var activityViewModel: ActivityRoundsViewModel
    @StateObject private var followingViewModel: FollowingRoundsViewModel

    @State private var selectedSegment: RoundsSegment = .nearby
    @State private var showingCreateRound = false
    @State private var showingFilters = false
    @State private var selectedRound: Round?
    
    init(
        nearbyViewModel: RoundsListViewModel,
        activityViewModel: ActivityRoundsViewModel,
        followingViewModel: FollowingRoundsViewModel
    ) {
        _nearbyViewModel = StateObject(wrappedValue: nearbyViewModel)
        _activityViewModel = StateObject(wrappedValue: activityViewModel)
        _followingViewModel = StateObject(wrappedValue: followingViewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColors.backgroundGrouped.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    segmentedControl
                    
                    // Content area per segment (includes segment-specific header)
                    segmentContent
                }
                
                // Floating action button (always visible)
                floatingActionButton
            }
            .navigationTitle("Rounds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
                // Load current segment
                await loadSegment(selectedSegment)

                // Preload other segments in background to reduce lag
                Task {
                    await preloadOtherSegments()
                }
            }
            .onChange(of: selectedSegment) { _, newSegment in
                Task { await loadSegment(newSegment) }
            }
            .onChange(of: deepLinkCoordinator.navigationTrigger) { _, roundId in
                // Handle deep link navigation
                if let roundId = roundId {
                    handleDeepLinkNavigation(roundId: roundId)
                }
            }
            .animation(.none, value: selectedSegment)
        }
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        Picker("Segment", selection: $selectedSegment) {
            ForEach(RoundsSegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Filter Summary (Nearby only)
    
    private var filterSummaryRow: some View {
        Button { showingFilters = true } label: {
            FilterSummaryView(filters: nearbyViewModel.filters, userProfile: nearbyViewModel.userProfile)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Segment Content
    
    @ViewBuilder
    private var segmentContent: some View {
        switch selectedSegment {
        case .nearby:
            VStack(spacing: 0) {
                filterSummaryRow
                NearbyRoundsContent(
                    viewModel: nearbyViewModel,
                    onRoundTap: { selectedRound = $0 },
                    onCreateRound: { attemptCreateRound() },
                    onShowFilters: { showingFilters = true }
                )
            }
            .refreshable { await nearbyViewModel.refresh() }
            
        case .activity:
            ActivityRoundsViewRefactored(
                viewModel: activityViewModel,
                onRoundTap: { selectedRound = $0 },
                onCreateRound: { attemptCreateRound() },
                onSwitchToNearby: { selectedSegment = .nearby }
            )
            .refreshable { await activityViewModel.refresh() }
            
        case .following:
            FollowingRoundsView(
                viewModel: followingViewModel,
                onRoundTap: { selectedRound = $0 },
                onSwitchToNearby: { selectedSegment = .nearby }
            )
            .refreshable { await followingViewModel.refresh() }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if selectedSegment == .nearby {
                filterButton
            }
        }
    }
    
    private var filterButton: some View {
        Button { showingFilters = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(AppColors.primary)
                
                if nearbyViewModel.hasActiveFilters {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
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
                .background(AppColors.primary)
                .clipShape(Circle())
                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, AppSpacing.contentPadding)
        .padding(.bottom, AppSpacing.lg)
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
        case .following:
            await followingViewModel.loadRounds()
        }
    }
    
    private func refreshCurrentSegment() {
        Task {
            switch selectedSegment {
            case .nearby: await nearbyViewModel.refresh()
            case .activity: await activityViewModel.refresh()
            case .following: await followingViewModel.refresh()
            }
        }
    }

    private func preloadOtherSegments() async {
        // Load segments that aren't currently selected in the background
        switch selectedSegment {
        case .nearby:
            // Preload Activity and Following
            async let activity: () = activityViewModel.loadActivity()
            async let following: () = followingViewModel.loadRounds()
            await activity
            await following

        case .activity:
            // Preload Nearby and Following
            async let nearby: () = nearbyViewModel.loadRounds()
            async let following: () = followingViewModel.loadRounds()
            await nearby
            await following

        case .following:
            // Preload Nearby and Activity
            async let nearby: () = nearbyViewModel.loadRounds()
            async let activity: () = activityViewModel.loadActivity()
            await nearby
            await activity
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
