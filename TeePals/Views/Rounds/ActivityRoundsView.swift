import SwiftUI

/// Activity segment view showing Hosting + Requested rounds.
struct ActivityRoundsView: View {
    
    @ObservedObject var viewModel: ActivityRoundsViewModel
    let onRoundTap: (Round) -> Void
    let onCreateRound: () -> Void
    let onSwitchToNearby: () -> Void
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.isEmpty {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.isEmpty {
                errorState(error)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                contentList
            }
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCard(style: .roundCard)
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.top, AppSpacing.sm)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Error State
    
    private func errorState(_ message: String) -> some View {
        ScrollView {
            VStack {
                Spacer(minLength: AppSpacing.xxl)
                InlineErrorBanner(message, actionTitle: "Retry") {
                    Task { await viewModel.loadActivity() }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                Spacer()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ActivityEmptyState(
            onCreateRound: onCreateRound,
            onBrowseNearby: onSwitchToNearby
        )
    }
    
    // MARK: - Content List
    
    private var contentList: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                hostingSection
                requestedSection
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Hosting Section

    private var hostingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Hosting", count: viewModel.hostingRounds.count)

            if viewModel.isLoadingHosting {
                // Show skeleton while loading
                SkeletonCard(style: .roundCard)
            } else if viewModel.hasHostingRounds {
                ForEach(viewModel.hostingRounds) { round in
                    RoundCardView(
                        round: round,
                        hostProfile: viewModel.currentUserProfile,
                        badge: .hosting,
                        context: .activity,
                        onTap: { onRoundTap(round) }
                    )
                }
            } else {
                sectionEmptyState(
                    message: "Create a round to start hosting",
                    actionTitle: "Create Round",
                    action: onCreateRound
                )
            }
        }
    }
    
    // MARK: - Requested Section

    private var requestedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(title: "Requests", count: viewModel.requestedRounds.count)

            if viewModel.isLoadingRequested {
                // Show skeleton while loading
                SkeletonCard(style: .roundCard)
            } else if viewModel.hasRequestedRounds {
                ForEach(viewModel.requestedRounds) { request in
                    RoundCardView(
                        round: request.round,
                        hostProfile: viewModel.hostProfile(for: request.round),
                        badge: badge(for: request.status),
                        context: .activity,
                        onTap: { onRoundTap(request.round) }
                    )
                }
            } else {
                sectionEmptyState(
                    message: "Request to join rounds nearby",
                    actionTitle: "Browse Nearby",
                    action: onSwitchToNearby
                )
            }
        }
    }
    
    // MARK: - Section Empty State
    
    private func sectionEmptyState(message: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
            
            Button(actionTitle) {
                action()
            }
            .font(AppTypography.labelMedium)
            .foregroundColor(AppColors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundSecondary.opacity(0.5))
        .cornerRadius(AppSpacing.radiusMedium)
    }
    
    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            Text("\(count)")
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 2)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppSpacing.radiusSmall)

            Spacer()
        }
    }

    // MARK: - Badge Mapping

    private func badge(for status: MemberStatus) -> RoundCardBadge {
        switch status {
        case .requested: return .requested
        case .accepted: return .confirmed
        case .declined: return .declined
        case .invited: return .invited
        case .removed, .left: return .declined
        }
    }
}

// MARK: - Activity Empty State

/// Empty state centered vertically in available space.
/// Uses ScrollView + Spacers pattern for consistent centering across all segments.
struct ActivityEmptyState: View {
    let onCreateRound: () -> Void
    let onBrowseNearby: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer(minLength: AppSpacing.xxl)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.primary.opacity(0.4))
                
                VStack(spacing: AppSpacing.sm) {
                    Text("No Activity Yet")
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Rounds you host or request will appear here.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: AppSpacing.md) {
                    PrimaryButton("Create Round", icon: "plus") {
                        onCreateRound()
                    }
                    .frame(maxWidth: 200)
                    
                    Button("Browse Nearby") {
                        onBrowseNearby()
                    }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primary)
                }
                
                Spacer()
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }
}

