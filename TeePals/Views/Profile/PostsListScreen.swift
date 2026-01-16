import SwiftUI

/// Dedicated full-screen view for browsing a user's posts.
/// Used when tapping "My Posts →" from profile.
struct PostsListScreen: View {
    let uid: String
    @EnvironmentObject var container: AppContainer
    @State private var showingCreatePost = false
    @State private var refreshTrigger = false

    var body: some View {
        UserPostsListView(
            viewModel: container.makeUserPostsViewModel(uid: uid),
            onCreatePost: { showingCreatePost = true },
            refreshTrigger: refreshTrigger
        )
        .navigationTitle("Posts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreatePost = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView(
                viewModel: container.makeCreatePostViewModel(),
                onPostCreated: { _ in
                    showingCreatePost = false
                    refreshTrigger.toggle()
                }
            )
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PostsListScreen(uid: "preview-user")
            .environmentObject(AppContainer())
    }
}
#endif
