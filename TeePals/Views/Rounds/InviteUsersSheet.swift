import SwiftUI

/// Sheet for inviting users from your following list to a round.
struct InviteUsersSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: InviteUsersViewModel

    init(viewModel: InviteUsersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                ZStack {
                    AppColors.backgroundGrouped
                        .ignoresSafeArea()

                    Group {
                        if viewModel.isLoading && viewModel.isEmpty {
                            loadingState
                        } else if viewModel.isEmpty {
                            emptyState
                        } else {
                            usersList
                        }
                    }
                }
            }
            .navigationTitle("Invite to Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadFollowing()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)

            TextField("Search", text: $viewModel.searchText)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusSmall)
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: AppSpacing.sm) {
                Text("No One to Invite")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Follow golfers to invite them to your rounds")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(AppSpacing.contentPadding)
    }

    // MARK: - Users List

    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredUsers) { user in
                    InviteUserRow(
                        user: user,
                        memberStatus: viewModel.getMemberStatus(user.id ?? ""),
                        isInviting: viewModel.isInvitingUser(user.id ?? ""),
                        onInvite: {
                            Task {
                                if let uid = user.id {
                                    await viewModel.inviteUser(uid)
                                }
                            }
                        }
                    )
                    Divider()
                }
            }
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.radiusMedium)
            .padding(AppSpacing.contentPadding)
        }
    }
}

// MARK: - Invite User Row

struct InviteUserRow: View {

    let user: PublicProfile
    let memberStatus: MemberStatus?
    let isInviting: Bool
    let onInvite: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Avatar
            if let photoUrl = user.photoUrls.first, let url = URL(string: photoUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsView
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                initialsView
            }

            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.nickname)
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textPrimary)

                Text(user.primaryCityLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Status indicator or invite button
            if let status = memberStatus, !canBeReinvited(status) {
                statusBadge(for: status)
            } else if isInviting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button {
                    onInvite()
                } label: {
                    Text("Invite")
                        .font(AppTypography.labelMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.primary)
                        .cornerRadius(AppSpacing.radiusSmall)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    private func canBeReinvited(_ status: MemberStatus) -> Bool {
        // Users with these statuses can be re-invited
        switch status {
        case .removed, .declined, .left:
            return true
        case .accepted, .invited, .requested:
            return false
        }
    }

    @ViewBuilder
    private func statusBadge(for status: MemberStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon(for: status))
                .font(.caption)
            Text(statusText(for: status))
                .font(AppTypography.labelMedium)
        }
        .foregroundColor(statusColor(for: status))
    }

    private func statusIcon(for status: MemberStatus) -> String {
        switch status {
        case .accepted: return "checkmark.circle.fill"
        case .invited: return "envelope"
        case .requested: return "clock"
        case .declined: return "xmark.circle"
        case .removed: return "xmark.circle"
        case .left: return "arrow.left.circle"
        }
    }

    private func statusText(for status: MemberStatus) -> String {
        switch status {
        case .accepted: return "Joined"
        case .invited: return "Invited"
        case .requested: return "Requested"
        case .declined: return "Declined"
        case .removed: return "Removed"
        case .left: return "Left"
        }
    }

    private func statusColor(for status: MemberStatus) -> Color {
        switch status {
        case .accepted: return AppColors.success
        case .invited: return AppColors.primary
        case .requested: return AppColors.textSecondary
        case .declined: return AppColors.error
        case .removed: return AppColors.error
        case .left: return AppColors.textSecondary
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(user.nickname.prefix(1)))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.primary)
            )
    }
}
