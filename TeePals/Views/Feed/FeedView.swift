import SwiftUI

/// Main feed view for the Home tab.
/// Shows posts with filter toggle and pull-to-refresh.
struct FeedView: View {
    
    @StateObject private var viewModel: FeedViewModel
    @EnvironmentObject var container: AppContainer
    
    @State private var showCreatePost = false
    @State private var selectedPost: Post?
    @State private var selectedAuthorUid: String?
    @State private var roundDetail: RoundDetailIdentifier?
    
    init(viewModel: FeedViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped
                    .ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading && viewModel.posts.isEmpty {
                        loadingState
                    } else if viewModel.isEmpty {
                        emptyState
                    } else {
                        feedContent
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    filterPicker
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreatePost = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCreatePost) {
                CreatePostView(
                    viewModel: container.makeCreatePostViewModel(),
                    onPostCreated: { post in
                        viewModel.postCreated(post)
                    }
                )
            }
            .sheet(item: $selectedPost) { post in
                PostDetailSheet(
                    postId: post.id ?? "",
                    container: container,
                    onDeleted: { postId in
                        viewModel.postDeleted(postId)
                    },
                    onUpdated: { updatedPost in
                        viewModel.postUpdated(updatedPost)
                    }
                )
            }
            .sheet(item: Binding(
                get: { selectedAuthorUid.map { IdentifiableString(value: $0) } },
                set: { selectedAuthorUid = $0?.value }
            )) { wrapper in
                if wrapper.value == viewModel.uid {
                    // Show own profile
                    NavigationStack {
                        ProfileView(viewModel: container.makeProfileViewModel())
                    }
                } else {
                    // Show other user's profile
                    NavigationStack {
                        OtherUserProfileView(
                            viewModel: container.makeOtherUserProfileViewModel(uid: wrapper.value)
                        )
                    }
                }
            }
            .fullScreenCover(item: $roundDetail) { item in
                RoundDetailCover(roundId: item.roundId)
                    .environmentObject(container)
            }
            .task {
                await viewModel.loadFeed()
            }
        }
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        Menu {
            ForEach(FeedFilter.allCases, id: \.self) { filter in
                Button {
                    Task { await viewModel.setFilter(filter) }
                } label: {
                    HStack {
                        Text(filter.displayText)
                        if viewModel.filter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.filter.displayText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.sm)
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCard(style: .standard)
                }
            }
            .padding(AppSpacing.contentPadding)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xxl)
                
                Image(systemName: "text.bubble")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.textTertiary)
                
                Text(viewModel.filter == .friendsOnly ? "No posts from friends yet" : "No posts yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(viewModel.filter == .friendsOnly
                     ? "Follow more golfers to see their posts here"
                     : "Be the first to share something!")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                PrimaryButton("Create Post", isLoading: false) {
                    showCreatePost = true
                }
                .frame(width: 160)
                
                Spacer()
            }
            .padding(AppSpacing.contentPadding)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Feed Content
    
    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(viewModel.posts) { post in
                    PostCardView(
                        post: post,
                        linkedRound: post.linkedRoundId != nil ? viewModel.linkedRounds[post.linkedRoundId!] : nil,
                        onTap: {
                            selectedPost = post
                        },
                        onUpvote: {
                            Task { await viewModel.toggleUpvote(for: post) }
                        },
                        onAuthorTap: {
                            selectedAuthorUid = post.authorUid
                        },
                        onRoundTap: { roundId in
                            roundDetail = RoundDetailIdentifier(roundId: roundId)
                        }
                    )
                    .onAppear {
                        // Load more when reaching near the end
                        if post.id == viewModel.posts.dropLast(3).last?.id {
                            Task { await viewModel.loadMore() }
                        }
                    }
                }
                
                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(AppSpacing.contentPadding)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Post Detail Sheet

private struct PostDetailSheet: View {
    let postId: String
    let container: AppContainer
    let onDeleted: (String) -> Void
    let onUpdated: (Post) -> Void
    
    var body: some View {
        NavigationStack {
            PostDetailView(
                viewModel: container.makePostDetailViewModel(postId: postId),
                onDeleted: onDeleted,
                onUpdated: onUpdated
            )
            .environmentObject(container)
        }
    }
}

// MARK: - Identifiable String Wrapper

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Preview

#if DEBUG
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView(viewModel: FeedViewModel(
            postsRepository: MockPostsRepository(),
            socialRepository: MockSocialRepository(),
            profileRepository: MockProfileRepository(),
            roundsRepository: MockRoundsRepository(),
            currentUid: { "user1" }
        ))
        .environmentObject(AppContainer())
    }
}

// Mocks for preview
private class MockPostsRepository: PostsRepository {
    func createPost(_ post: Post) async throws -> Post { post }
    func fetchPost(id: String) async throws -> Post? { nil }
    func updatePost(_ post: Post) async throws {}
    func deletePost(id: String) async throws {}
    func updateAuthorProfile(uid: String, nickname: String, photoUrl: String?) async throws {}
    func updateCommentAuthorProfile(uid: String, nickname: String, photoUrl: String?) async throws {}
    func fetchFeed(filter: FeedFilter, limit: Int, after: Date?) async throws -> [Post] { [] }
    func fetchUserPosts(uid: String, limit: Int, after: Date?) async throws -> [Post] { [] }
    func toggleUpvote(postId: String) async throws -> Bool { false }
    func hasUpvoted(postId: String) async throws -> Bool { false }
    func createComment(_ comment: Comment) async throws -> Comment { comment }
    func fetchComments(postId: String) async throws -> [Comment] { [] }
    func updateComment(_ comment: Comment) async throws {}
    func deleteComment(postId: String, commentId: String) async throws {}
    func toggleCommentLike(postId: String, commentId: String) async throws -> Bool { false }
    func hasLikedComment(postId: String, commentId: String) async throws -> Bool { false }

    // Phase 4.2 methods
    func fetchFriendsPostsCandidates(authorUids: [String], windowStart: Date, limit: Int) async throws -> [Post] { [] }
    func fetchRecentPublicPosts(windowStart: Date, limit: Int) async throws -> [Post] { [] }
    func fetchTrendingPostIds(limit: Int) async throws -> [(String, Double)] { [] }
    func fetchPostsByIds(_ ids: [String]) async throws -> [Post] { [] }
    func fetchNewCreatorsPosts(windowStart: Date, limit: Int) async throws -> [Post] { [] }
    func fetchPostStats(postId: String) async throws -> PostStats? { nil }
    func fetchPostStatsBatch(postIds: [String]) async throws -> [String: PostStats] { [:] }
    func fetchUserStats(uid: String) async throws -> UserStats? { nil }
    func fetchUserStatsBatch(uids: [String]) async throws -> [String: UserStats] { [:] }
}

private class MockSocialRepository: SocialRepository {
    func follow(targetUid: String) async throws {}
    func unfollow(targetUid: String) async throws {}
    func isFollowing(targetUid: String) async throws -> Bool { false }
    func isFollowedBy(targetUid: String) async throws -> Bool { false }
    func isMutualFollow(targetUid: String) async throws -> Bool { false }
    func getFollowing() async throws -> [String] { [] }
    func getFollowers() async throws -> [String] { [] }
    func getFriends() async throws -> [String] { [] }
    func getFollowerCount(uid: String) async throws -> Int { 0 }
    func getFollowingCount(uid: String) async throws -> Int { 0 }
    func fetchMutualFollows(uid: String) async throws -> [FollowUser] { [] }
    func areMutualFollows(uid1: String, uid2: String) async throws -> Bool { false }
    func fetchFollowersWithProfiles(uid: String) async throws -> [FollowUser] { [] }
    func fetchFollowingWithProfiles(uid: String) async throws -> [FollowUser] { [] }
}

private class MockProfileRepository: ProfileRepository {
    func profileExists(uid: String) async throws -> Bool { false }
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}

private class MockRoundsRepository: RoundsRepository {
    func createRound(_ round: Round) async throws -> Round { round }
    func fetchRound(id: String) async throws -> Round? { nil }
    func fetchRounds(filters: RoundFilters, limit: Int, lastRound: Round?) async throws -> [Round] { [] }
    func updateRound(_ round: Round) async throws {}
    func cancelRound(id: String) async throws {}
    func fetchMembers(roundId: String) async throws -> [RoundMember] { [] }
    func requestToJoin(roundId: String) async throws {}
    func joinRound(roundId: String) async throws {}
    func acceptMember(roundId: String, memberUid: String) async throws {}
    func declineMember(roundId: String, memberUid: String) async throws {}
    func removeMember(roundId: String, memberUid: String) async throws {}
    func leaveRound(roundId: String) async throws {}
    func inviteMember(roundId: String, targetUid: String) async throws {}
    func fetchMembershipStatus(roundId: String) async throws -> RoundMember? { nil }
    func fetchInvitedRounds() async throws -> [Round] { [] }
    func acceptInvite(roundId: String) async throws {}
    func declineInvite(roundId: String) async throws {}
}
#endif

