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
        VStack(spacing: AppSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCard(style: .standard)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(AppSpacing.contentPadding)
    }
    
    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "text.bubble")
                    .font(.largeTitle)
                    .foregroundColor(AppColors.textTertiary)

                Text("No posts yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Share your first update with golfers nearby.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                if let onCreate = onCreatePost {
                    Button {
                        onCreate()
                    } label: {
                        Text("Create Post")
                            .font(AppTypography.buttonMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: 200)
                            .frame(height: AppSpacing.buttonHeightLarge)
                            .background(AppColors.primary)
                            .cornerRadius(AppRadii.button)
                    }
                    .padding(.top, AppSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.contentPadding)

            Spacer()
        }
    }
    
    // MARK: - Posts List

    private var postsList: some View {
        LazyVStack(spacing: AppSpacing.md, pinnedViews: []) {
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
        .padding(AppSpacing.contentPadding)
    }
}

// MARK: - Compact Post Row

struct CompactPostRow: View {
    let post: Post
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                // First photo thumbnail if available
                if let firstPhoto = post.photoUrls.first, let url = URL(string: firstPhoto) {
                    TPImage(url: url)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.text)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: AppSpacing.sm) {
                        Text(post.timeAgoString)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                            Text("\(post.upvoteCount)")
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                            Text("\(post.commentCount)")
                        }
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }
}

