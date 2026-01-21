import SwiftUI

/// Content view for the Nearby segment (existing discovery/geo search).
struct NearbyRoundsContent: View {
    
    @ObservedObject var viewModel: RoundsListViewModel
    let onRoundTap: (Round) -> Void
    let onCreateRound: () -> Void
    let onShowFilters: () -> Void
    
    var body: some View {
        ScrollView {
            if viewModel.shouldShowSkeleton {
                loadingState
            } else if let error = viewModel.errorMessage {
                errorStateContent(error)
            } else if viewModel.hasRounds {
                roundsListContent
            } else {
                emptyState
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCard(style: .roundCard)
            }
        }
        .padding(AppSpacing.contentPadding)
        .padding(.bottom, 100)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        RoundsEmptyState(
            onEditFilters: onShowFilters,
            onCreateRound: onCreateRound
        )
    }
    
    // MARK: - Error State

    private func errorStateContent(_ message: String) -> some View {
        VStack {
            Spacer(minLength: AppSpacing.xxl)

            InlineErrorBanner(message, actionTitle: "Retry") {
                viewModel.errorMessage = nil
                Task { await viewModel.loadRounds() }
            }
            .padding(.horizontal, AppSpacing.contentPadding)

            Spacer()
        }
    }

    // MARK: - Rounds List

    private var roundsListContent: some View {
        LazyVStack(spacing: AppSpacing.md) {
            ForEach(viewModel.rounds) { round in
                RoundCardView(
                    round: round,
                    hostProfile: viewModel.hostProfile(for: round),
                    context: .nearby,
                    onTap: { onRoundTap(round) }
                )
                .onAppear {
                    Task {
                        await viewModel.loadMoreIfNeeded(currentRound: round)
                    }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding()
            }
        }
        .padding(AppSpacing.contentPadding)
        .padding(.bottom, 100)
    }
}

