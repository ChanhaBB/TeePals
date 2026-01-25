import SwiftUI

/// Unified Activity view - consolidates Hosting, Participating, and Invited.
struct ActivityRoundsViewV2: View {

    @ObservedObject var viewModel: ActivityRoundsViewModelV2

    let onRoundTap: (Round) -> Void
    let onCreateRound: () -> Void
    let onSwitchToNearby: () -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasLoadedOnce {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.isEmpty {
                errorState(error)
            } else if viewModel.isEmpty {
                emptyState
            } else {
                contentView
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

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Sections
                ForEach([ActivitySection.actionRequired, .upcoming, .pendingApproval, .past], id: \.self) { section in
                    sectionView(for: section)
                }
            }
            .padding(.bottom, 100) // Space for FAB
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Section View

    @ViewBuilder
    private func sectionView(for section: ActivitySection) -> some View {
        let rounds = viewModel.groupedRounds[section] ?? []

        CollapsibleSection(
            section: section,
            count: rounds.count,
            isExpanded: viewModel.isSectionExpanded(section),
            onToggle: { viewModel.toggleSection(section) }
        ) {
            if rounds.isEmpty && section == .actionRequired {
                // Show placeholder for empty Action Required
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(AppColors.success)

                    Text("All caught up! No actions needed.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()
                }
                .padding(AppSpacing.md)
                .background(AppColors.backgroundSecondary.opacity(0.5))
                .cornerRadius(AppSpacing.radiusMedium)
            } else {
                ForEach(rounds) { item in
                    if item.status == .invited {
                        // Show invited card with accept/decline buttons
                        InvitedRoundCard(
                            round: item.round,
                            inviterName: item.inviterName,
                            onTap: { onRoundTap(item.round) },
                            onAccept: {
                                Task {
                                    if let roundId = item.round.id {
                                        await viewModel.acceptInvite(roundId: roundId)
                                    }
                                }
                            },
                            onDecline: {
                                Task {
                                    if let roundId = item.round.id {
                                        await viewModel.declineInvite(roundId: roundId)
                                    }
                                }
                            }
                        )
                    } else if item.role == .hosting && item.round.requestCount > 0 {
                        // Show hosting card with pending requests pill overlay
                        ZStack(alignment: .topTrailing) {
                            RoundCardView(
                                round: item.round,
                                hostProfile: item.hostProfile,
                                badge: .hosting,
                                context: .activity,
                                onTap: { onRoundTap(item.round) }
                            )

                            // Pending requests pill (positioned next to HOSTING badge)
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 9))
                                Text("\(item.round.requestCount) Pending")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.warning.opacity(0.15))
                            .cornerRadius(AppSpacing.radiusSmall)
                            .offset(x: -12, y: 44) // Position below HOSTING badge
                        }
                    } else {
                        // Show regular round card
                        RoundCardView(
                            round: item.round,
                            hostProfile: item.hostProfile,
                            badge: item.badge,
                            context: .activity,
                            onTap: { onRoundTap(item.round) }
                        )
                    }
                }
            }
        }
    }
}
