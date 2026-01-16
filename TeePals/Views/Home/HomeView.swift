import SwiftUI

/// Home tab view - shows the social feed.
/// Delegates to FeedView for actual content.
struct HomeView: View {
    
    @EnvironmentObject var container: AppContainer
    
    var body: some View {
        FeedView(viewModel: container.makeFeedViewModel())
            .environmentObject(container)
    }
}

// MARK: - Preview

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppContainer())
    }
}
#endif
