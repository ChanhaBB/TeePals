import SwiftUI

/// View displaying a user's posts on their profile.
/// Supports loading, empty state, and navigation to post detail.
struct UserPostsListView: View {

    @StateObject private var viewModel: UserPostsViewModel
    @EnvironmentObject var container: AppContainer

    @State private var selectedPost: Post?
    let onCreatePost: (() -> Void)?
    let refreshTrigger: Bool

    init(viewModel: UserPostsViewModel, onCreatePost: (() -> Void)? = nil, refreshTrigger: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCreatePost = onCreatePost
        self.refreshTrigger = refreshTrigger
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    loadingState
                } else if viewModel.isEmpty {
                    emptyState
                } else {
                    postsList
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .sheet(item: $selectedPost) { post in
            NavigationStack {
                PostDetailView(
                    viewModel: container.makePostDetailViewModel(postId: post.id ?? ""),
                    onDeleted: { postId in
                        viewModel.postDeleted(postId)
                        selectedPost = nil
                    },
                    onUpdated: { updatedPost in
                        viewModel.postUpdated(updatedPost)
                    }
                )
            }
        }
        .task {
            await viewModel.loadPosts()
        }
        .onChange(of: refreshTrigger) { _, _ in
            Task {
                await viewModel.loadPosts()
            }
        }
    }
    
    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: AppSpacingV3.sm) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCard(style: .standard)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(AppSpacingV3.md)
    }
    
    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()

            VStack(spacing: AppSpacingV3.sm) {
                Image(systemName: "text.bubble")
                    .font(.largeTitle)
                    .foregroundColor(AppColorsV3.textTertiary)

                Text("No posts yet")
                    .font(AppTypographyV3.headlineMedium)
                    .foregroundColor(AppColorsV3.textPrimary)

                Text("Share your first update with golfers nearby.")
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .multilineTextAlignment(.center)

                if let onCreate = onCreatePost {
                    PrimaryButtonV3("Create Post", size: .medium) {
                        onCreate()
                    }
                    .frame(maxWidth: 200)
                    .padding(.top, AppSpacingV3.xs)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacingV3.md)

            Spacer()
        }
    }
    
    // MARK: - Posts List

    private var postsList: some View {
        LazyVStack(spacing: AppSpacingV3.sm, pinnedViews: []) {
            ForEach(viewModel.posts) { post in
                CompactPostRow(post: post) {
                    selectedPost = post
                }
                .onAppear {
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
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(AppSpacingV3.md)
    }
}

// MARK: - Compact Post Row

struct CompactPostRow: View {
    let post: Post
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: AppSpacingV3.xs) {
                if let firstPhoto = post.photoUrls.first, let url = URL(string: firstPhoto) {
                    TPImage(url: url)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.xxs))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.text)
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: AppSpacingV3.xs) {
                        Text(post.timeAgoString)
                            .font(AppTypographyV3.caption)
                            .foregroundColor(AppColorsV3.textTertiary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                            Text("\(post.upvoteCount)")
                        }
                        .font(AppTypographyV3.caption)
                        .foregroundColor(AppColorsV3.textTertiary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                            Text("\(post.commentCount)")
                        }
                        .font(AppTypographyV3.caption)
                        .foregroundColor(AppColorsV3.textTertiary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColorsV3.textTertiary)
            }
            .padding(AppSpacingV3.xs)
            .background(AppColorsV3.surfaceWhite)
            .cornerRadius(AppSpacingV3.xs)
        }
        .buttonStyle(.plain)
    }
}
