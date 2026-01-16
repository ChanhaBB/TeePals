import Foundation

/// ViewModel for displaying a user's posts on their profile.
@MainActor
final class UserPostsViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let postsRepository: PostsRepository
    private let targetUid: String
    
    // MARK: - State
    
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    
    // Pagination
    private var lastPostDate: Date?
    
    // MARK: - Init
    
    init(
        targetUid: String,
        postsRepository: PostsRepository
    ) {
        self.targetUid = targetUid
        self.postsRepository = postsRepository
    }
    
    // MARK: - Computed
    
    var isEmpty: Bool { posts.isEmpty && !isLoading }
    
    // MARK: - Load Posts
    
    func loadPosts() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedPosts = try await postsRepository.fetchUserPosts(
                uid: targetUid,
                limit: FeedConstants.defaultPageSize,
                after: nil
            )
            
            posts = fetchedPosts
            lastPostDate = fetchedPosts.last?.createdAt
            hasMorePosts = fetchedPosts.count >= FeedConstants.defaultPageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Load More
    
    func loadMore() async {
        guard !isLoadingMore, hasMorePosts, let cursor = lastPostDate else { return }
        
        isLoadingMore = true
        
        do {
            let morePosts = try await postsRepository.fetchUserPosts(
                uid: targetUid,
                limit: FeedConstants.defaultPageSize,
                after: cursor
            )
            
            posts.append(contentsOf: morePosts)
            lastPostDate = morePosts.last?.createdAt ?? lastPostDate
            hasMorePosts = morePosts.count >= FeedConstants.defaultPageSize
        } catch {
            print("Load more failed: \(error)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Post Updates
    
    func postDeleted(_ postId: String) {
        posts.removeAll { $0.id == postId }
    }
    
    func postUpdated(_ post: Post) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
        }
    }
}





