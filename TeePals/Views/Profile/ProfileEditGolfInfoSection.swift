import SwiftUI

/// Golf Info section for ProfileEditView.
/// Contains: Average Score (dropdown), Experience Level (picker)
struct ProfileEditGolfInfoSection: View {
    @ObservedObject var viewModel: ProfileEditViewModel
    
    var body: some View {
        Section {
            avgScorePicker
            experienceLevelPicker
        } header: {
            Text("Golf Info")
        } footer: {
            Text("This info helps match you with compatible players.")
        }
    }
    
    // MARK: - Average Score
    
    private var avgScorePicker: some View {
        FormFieldRow(icon: "number") {
            Picker("Average Score (18 holes)", selection: $viewModel.avgScore) {
                Text("Not set").tag(Int?.none)
                ForEach(AvgScoreOption.allCases) { option in
                    Text(option.displayText).tag(Int?.some(option.rawValue))
                }
            }
        }
    }
    
    // MARK: - Experience Level
    
    private var experienceLevelPicker: some View {
        FormFieldRow(icon: "clock.fill") {
            Picker("Experience", selection: $viewModel.experienceLevel) {
                Text("Not set").tag(ExperienceLevel?.none)
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    Text(level.displayText).tag(ExperienceLevel?.some(level))
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Form {
        ProfileEditGolfInfoSection(
            viewModel: ProfileEditViewModel(
                profileRepository: MockProfileRepo(),
                storageService: MockStorageService(),
                postsRepository: MockPostsRepo(),
                currentUid: { "preview" }
            )
        )
    }
}

private class MockProfileRepo: ProfileRepository {
    func profileExists(uid: String) async throws -> Bool { false }
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}

private class MockStorageService: StorageServiceProtocol {
    func uploadProfilePhoto(_ imageData: Data) async throws -> String { "" }
    func deleteProfilePhoto(url: String) async throws {}
    func uploadPostPhoto(_ imageData: Data, postId: String?) async throws -> String { "" }
    func deletePostPhoto(url: String) async throws {}
    func uploadChatPhoto(_ imageData: Data, roundId: String, messageId: String?) async throws -> String { "" }
}

private class MockPostsRepo: PostsRepository {
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
#endif

