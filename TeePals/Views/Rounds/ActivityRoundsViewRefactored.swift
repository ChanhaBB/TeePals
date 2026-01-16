import SwiftUI

/// Activity segment with subtabs: Hosting | Participating | Invited
struct ActivityRoundsViewRefactored: View {

    @ObservedObject var viewModel: ActivityRoundsViewModel

    let onRoundTap: (Round) -> Void
    let onCreateRound: () -> Void
    let onSwitchToNearby: () -> Void

    @State private var selectedSubtab: ActivitySubtab = .hosting

    init(
        viewModel: ActivityRoundsViewModel,
        onRoundTap: @escaping (Round) -> Void,
        onCreateRound: @escaping () -> Void,
        onSwitchToNearby: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onRoundTap = onRoundTap
        self.onCreateRound = onCreateRound
        self.onSwitchToNearby = onSwitchToNearby
    }

    var body: some View {
        VStack(spacing: 0) {
            subtabPicker

            subtabContent
        }
    }

    // MARK: - Subtab Picker

    private var subtabPicker: some View {
        HStack(spacing: AppSpacing.lg) {
            ForEach(ActivitySubtab.allCases) { subtab in
                Button {
                    selectedSubtab = subtab
                } label: {
                    VStack(spacing: 4) {
                        Text(subtab.title)
                            .font(AppTypography.labelMedium)
                            .foregroundColor(selectedSubtab == subtab ? AppColors.textPrimary : AppColors.textSecondary)

                        // Active indicator
                        Rectangle()
                            .fill(selectedSubtab == subtab ? AppColors.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xs)
        .background(AppColors.backgroundGrouped)
    }

    // MARK: - Subtab Content

    @ViewBuilder
    private var subtabContent: some View {
        switch selectedSubtab {
        case .hosting:
            hostingView
        case .joined:
            joinedView
        case .invited:
            invitedView
        }
    }

    private var hostingView: some View {
        ScrollView {
            if viewModel.shouldShowSkeleton {
                loadingState
            } else if viewModel.hostingRounds.isEmpty {
                hostingEmptyState
            } else {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.hostingRounds) { round in
                        RoundCardView(
                            round: round,
                            hostProfile: viewModel.currentUserProfile,
                            badge: .hosting,
                            context: .activity,
                            onTap: { onRoundTap(round) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 100)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var joinedView: some View {
        ScrollView {
            if viewModel.shouldShowSkeleton {
                loadingState
            } else if viewModel.requestedRounds.isEmpty {
                joinedEmptyState
            } else {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.requestedRounds) { request in
                        RoundCardView(
                            round: request.round,
                            hostProfile: viewModel.hostProfile(for: request.round),
                            badge: badge(for: request.status),
                            context: .activity,
                            onTap: { onRoundTap(request.round) }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 100)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var invitedView: some View {
        ScrollView {
            if viewModel.shouldShowSkeleton {
                loadingState
            } else if viewModel.invitedRounds.isEmpty {
                invitedEmptyState
            } else {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.invitedRounds) { round in
                        InvitedRoundCard(
                            round: round,
                            inviterName: viewModel.inviterName(for: round.id ?? ""),
                            onTap: { onRoundTap(round) },
                            onAccept: {
                                Task {
                                    if let roundId = round.id {
                                        await viewModel.acceptInvite(roundId: roundId)
                                    }
                                }
                            },
                            onDecline: {
                                Task {
                                    if let roundId = round.id {
                                        await viewModel.declineInvite(roundId: roundId)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 100)
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonCard(style: .roundCard)
            }
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Empty States

    private var hostingEmptyState: some View {
        emptyStateView(
            icon: "calendar.badge.clock",
            title: "No Rounds Hosted",
            message: "Create a round to start hosting",
            actionTitle: "Create Round",
            action: onCreateRound
        )
    }

    private var joinedEmptyState: some View {
        emptyStateView(
            icon: "hand.raised",
            title: "No Joined Rounds",
            message: "Request to join rounds nearby",
            actionTitle: "Browse Nearby",
            action: onSwitchToNearby
        )
    }

    private var invitedEmptyState: some View {
        emptyStateView(
            icon: "envelope",
            title: "No Invitations",
            message: "When friends invite you to rounds, they'll appear here",
            actionTitle: nil,
            action: nil
        )
    }

    private func emptyStateView(
        icon: String,
        title: String,
        message: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: AppSpacing.xxl)

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primary.opacity(0.4))

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)

                Text(message)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.primary)
            }

            Spacer()
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Badge Mapping

    private func badge(for status: MemberStatus) -> RoundCardBadge {
        switch status {
        case .requested: return .pending
        case .accepted: return .approved
        case .declined: return .declined
        case .invited: return .invited
        case .removed, .left: return .declined
        }
    }
}

// MARK: - Activity Subtab

enum ActivitySubtab: Int, CaseIterable, Identifiable {
    case hosting = 0
    case joined = 1
    case invited = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .hosting: return "Hosting"
        case .joined: return "Participating"
        case .invited: return "Invited"
        }
    }
}
