import SwiftUI

/// Followers / Following list with V3 design system.
struct FollowersListView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: AppContainer

    let uid: String
    let mode: ListMode
    /// The current viewer's uid — used to compute relationship badges from the viewer's perspective.
    var currentUserUid: String? = nil

    @State private var users: [FollowUser] = []
    @State private var filteredUsers: [FollowUser] = []
    /// UIDs that the current viewer follows (single-doc fetch, not full profiles).
    @State private var viewerFollowingUids: Set<String> = []
    /// UIDs that follow the current viewer back.
    @State private var viewerFollowerUids: Set<String> = []

    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasLoaded = false

    enum ListMode {
        case followers, following

        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
        var emptyIcon: String {
            switch self {
            case .followers: return "person.2"
            case .following: return "person.badge.plus"
            }
        }
        var emptyMessage: String {
            switch self {
            case .followers: return "No followers yet"
            case .following: return "Not following anyone"
            }
        }
    }

    // MARK: - Relationship Badge

    /// Relationship from the viewer's perspective, shown on each row.
    enum RelationshipBadge {
        case friend, following, followsYou

        var label: String {
            switch self {
            case .friend:     return "Friend"
            case .following:  return "Following"
            case .followsYou: return "Follows you"
            }
        }
        var icon: String {
            switch self {
            case .friend:     return "person.2.fill"
            case .following:  return "checkmark"
            case .followsYou: return "person.fill"
            }
        }
        var color: Color {
            switch self {
            case .friend:     return AppColorsV3.forestGreen
            case .following:  return AppColorsV3.forestGreen
            case .followsYou: return AppColorsV3.textSecondary
            }
        }
    }

    private func relationshipBadge(for user: FollowUser) -> RelationshipBadge? {
        let viewerFollows   = viewerFollowingUids.contains(user.uid)
        let userFollowsBack = viewerFollowerUids.contains(user.uid)
        if viewerFollows && userFollowsBack { return .friend }
        if viewerFollows                    { return .following }
        if userFollowsBack                  { return .followsYou }
        return nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColorsV3.bgNeutral.ignoresSafeArea()
            Group {
                if isLoading {
                    loadingState
                } else if let error = errorMessage {
                    errorState(error)
                } else if filteredUsers.isEmpty {
                    emptyState
                } else {
                    usersList
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        // No Done button — system back button handles dismissal.
        // navigationDestination(for: String.self) is registered at the NavigationStack root
        // (ProfileViewV3.profileBody) so it is NOT re-registered here to avoid "declared earlier" warnings.
        .onChange(of: searchText) { _, newValue in filterUsers(query: newValue) }
        .task {
            guard !hasLoaded else { return }
            await loadUsers()
        }
    }

    // MARK: - Users List (flat, sorted friends-first)

    private var usersList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(filteredUsers.enumerated()), id: \.element.id) { index, user in
                    VStack(spacing: 0) {
                        if index > 0 {
                            Divider()
                                .padding(.leading, AppSpacingV3.md + 44 + AppSpacingV3.md)
                        }
                        userRow(user)
                    }
                }
            }
            .background(AppColorsV3.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColorsV3.borderLight, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
            .padding(.horizontal, AppSpacingV3.contentPadding)
            .padding(.vertical, AppSpacingV3.md)
        }
    }

    private func userRow(_ user: FollowUser) -> some View {
        NavigationLink(value: user.uid) {
            HStack(spacing: AppSpacingV3.md) {
                TPAvatar(url: user.photoUrl.flatMap { URL(string: $0) }, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.nickname)
                        .font(AppTypographyV3.bodySemibold)
                        .foregroundColor(AppColorsV3.textPrimary)
                        .lineLimit(1)

                    if let badge = relationshipBadge(for: user) {
                        badgePill(badge)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColorsV3.textTertiary)
            }
            .padding(AppSpacingV3.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badgePill(_ badge: RelationshipBadge) -> some View {
        HStack(spacing: 4) {
            Image(systemName: badge.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(badge.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(badge.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(badge.color.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: AppSpacingV3.md) {
            ForEach(0..<5, id: \.self) { _ in skeletonRow }
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
        .padding(.top, AppSpacingV3.md)
    }

    private var skeletonRow: some View {
        HStack(spacing: AppSpacingV3.md) {
            Circle()
                .fill(AppColorsV3.surfaceLight)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(AppColorsV3.surfaceLight).frame(width: 120, height: 13)
                RoundedRectangle(cornerRadius: 4).fill(AppColorsV3.surfaceLight).frame(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColorsV3.borderLight, lineWidth: 1))
        .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacingV3.md) {
            Image(systemName: mode.emptyIcon)
                .font(.system(size: 44))
                .foregroundColor(AppColorsV3.textTertiary.opacity(0.5))
            Text(mode.emptyMessage)
                .font(AppTypographyV3.headlineMedium)
                .foregroundColor(AppColorsV3.textPrimary)
            if !searchText.isEmpty {
                Text("Try a different name")
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private func errorState(_ message: String) -> some View {
        VStack {
            Spacer(minLength: AppSpacingV3.xxl)
            InlineErrorBanner(message, actionTitle: "Retry") {
                errorMessage = nil
                Task { await loadUsers() }
            }
            .padding(.horizontal, AppSpacingV3.contentPadding)
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            // Parallel: main profile list + viewer's UID-only follow graph (single doc reads each)
            async let mainListTask = fetchMainList()
            async let followingTask = container.socialRepository.getFollowing()
            async let followersTask = container.socialRepository.getFollowers()

            let (mainList, following, followers) = try await (mainListTask, followingTask, followersTask)

            viewerFollowingUids = Set(following)
            viewerFollowerUids  = Set(followers)

            // Sort: mutual friends first, then "following", then "follows you", then alphabetical
            let sorted = mainList.sorted { lhs, rhs in
                let lb = badgeRank(lhs)
                let rb = badgeRank(rhs)
                if lb != rb { return lb < rb }
                return lhs.nickname.lowercased() < rhs.nickname.lowercased()
            }

            users = sorted
            filteredUsers = sorted
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
        hasLoaded = true
    }

    private func fetchMainList() async throws -> [FollowUser] {
        switch mode {
        case .followers: return try await container.socialRepository.fetchFollowersWithProfiles(uid: uid)
        case .following: return try await container.socialRepository.fetchFollowingWithProfiles(uid: uid)
        }
    }

    /// Rank for sorting: lower = higher priority.
    private func badgeRank(_ user: FollowUser) -> Int {
        let viewerFollows   = viewerFollowingUids.contains(user.uid)
        let userFollowsBack = viewerFollowerUids.contains(user.uid)
        if viewerFollows && userFollowsBack { return 0 }  // friend
        if viewerFollows                    { return 1 }  // following
        if userFollowsBack                  { return 2 }  // follows you
        return 3
    }

    private func filterUsers(query: String) {
        filteredUsers = query.isEmpty
            ? users
            : users.filter { $0.nickname.localizedCaseInsensitiveContains(query) }
    }
}

