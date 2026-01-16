import SwiftUI

/// Following segment view showing rounds from followed users.
struct FollowingRoundsView: View {
    
    @ObservedObject var viewModel: FollowingRoundsViewModel
    let onRoundTap: (Round) -> Void
    let onSwitchToNearby: () -> Void
    
    var body: some View {
        Group {
            if viewModel.shouldShowSkeleton {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.isEmpty {
                errorState(error)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                roundsList
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
                    Task { await viewModel.loadRounds() }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                Spacer()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        FollowingEmptyState(onBrowseNearby: onSwitchToNearby)
    }
    
    // MARK: - Rounds List
    
    private var roundsList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(viewModel.rounds) { round in
                    RoundCardView(
                        round: round,
                        hostProfile: viewModel.hostProfile(for: round),
                        badge: nil,
                        context: .following,
                        onTap: { onRoundTap(round) }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Following Empty State

/// Empty state centered vertically in available space.
/// Uses ScrollView + Spacers pattern for consistent centering across all segments.
struct FollowingEmptyState: View {
    let onBrowseNearby: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Spacer(minLength: AppSpacing.xxl)
                
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColors.primary.opacity(0.4))
                
                VStack(spacing: AppSpacing.sm) {
                    Text("No Rounds from Following")
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Rounds hosted by people you follow will appear here.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("Browse Nearby") {
                    onBrowseNearby()
                }
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.primary)
                
                Spacer()
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: .infinity)
        }
    }
}

