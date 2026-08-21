import SwiftUI

/// V3 sheet for inviting users from your following list to a round.
struct InviteUsersSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: InviteUsersViewModel

    init(viewModel: InviteUsersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            dragIndicator

            // Header
            sheetHeader

            // Content
            if viewModel.isLoading && viewModel.isEmpty {
                loadingState
            } else if viewModel.isEmpty {
                emptyState
            } else {
                sheetContent
            }
        }
        .background(AppColorsV3.surfaceWhite)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .task {
            await viewModel.loadFollowing()
        }
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 48, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Spacer()

            Button("Done") {
                dismiss()
            }
            .font(AppTypographyV3.bodySemibold)
            .foregroundColor(AppColorsV3.forestGreen)
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
        .padding(.vertical, 20)
        .overlay(
            Rectangle()
                .fill(AppColorsV3.borderLight)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Content

    private var sheetContent: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, AppSpacingV3.contentPadding)
                .padding(.vertical, AppSpacingV3.md)

            // Users list
            ScrollView {
                VStack(spacing: 0) {
                    // Suggested section
                    if !viewModel.suggestedUsers.isEmpty && viewModel.searchText.isEmpty {
                        sectionHeader("SUGGESTED")

                        ForEach(viewModel.suggestedUsers) { user in
                            InviteUserRowV3(
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

                            if user.id != viewModel.suggestedUsers.last?.id {
                                userDivider
                            }
                        }

                        Spacer()
                            .frame(height: AppSpacingV3.lg)
                    }

                    // All following section
                    let allUsers = viewModel.searchText.isEmpty ?
                        viewModel.allFollowingUsers : viewModel.filteredUsers

                    if !allUsers.isEmpty {
                        sectionHeader(viewModel.searchText.isEmpty ? "ALL FOLLOWING" : "SEARCH RESULTS")

                        ForEach(allUsers) { user in
                            InviteUserRowV3(
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

                            if user.id != allUsers.last?.id {
                                userDivider
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: AppSpacingV3.sm) {
            Image(systemName: "magnifyingglass")
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(viewModel.searchText.isEmpty ?
                    AppColorsV3.textSecondary : AppColorsV3.forestGreen)

            TextField("Search followers", text: $viewModel.searchText)
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textPrimary)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppSpacingV3.md)
        .padding(.vertical, AppSpacingV3.sm)
        .background(AppColorsV3.surfaceWhite)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall)
                .stroke(AppColorsV3.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypographyV3.bodySmall)
            .foregroundColor(AppColorsV3.textSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppSpacingV3.sm)
    }

    private var userDivider: some View {
        Rectangle()
            .fill(AppColorsV3.borderLight)
            .frame(height: 1)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacingV3.lg) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 56))
                .foregroundStyle(AppColorsV3.textSecondary)

            VStack(spacing: AppSpacingV3.sm) {
                Text("No One to Invite")
                    .font(AppTypographyV3.displayMediumSerif)
                    .foregroundColor(AppColorsV3.textPrimary)

                Text("Follow people on teepals to invite or share the round link!")
                    .font(AppTypographyV3.bodyRegular)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacingV3.lg)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacingV3.contentPadding)
    }
}

// MARK: - Invite User Row V3

struct InviteUserRowV3: View {

    let user: PublicProfile
    let memberStatus: MemberStatus?
    let isInviting: Bool
    let onInvite: () -> Void

    var body: some View {
        HStack(spacing: AppSpacingV3.md) {
            // Avatar
            TPAvatar(
                url: user.photoUrls.first.flatMap { URL(string: $0) },
                size: 44
            )

            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(AppTypographyV3.roundCardTitle)
                    .foregroundColor(AppColorsV3.textPrimary)

                Text(user.primaryCityLabel)
                    .font(AppTypographyV3.bodySmall)
                    .foregroundColor(AppColorsV3.textSecondary)
            }

            Spacer()

            // Status/Action
            statusView
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusView: some View {
        if memberStatus == .invited {
            // Invited - plain gray text (not clickable)
            Text("Invited")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColorsV3.textSecondary)
        } else if isInviting {
            // Loading
            ProgressView()
                .scaleEffect(0.8)
        } else {
            // Invite button - green outlined pill
            Button {
                onInvite()
            } label: {
                Text("Invite")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColorsV3.forestGreen)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacingV3.radiusFull)
                            .stroke(AppColorsV3.forestGreen, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
