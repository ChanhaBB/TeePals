import SwiftUI

/// Wrapper for presenting RoundDetailView as a fullScreenCover.
/// Uses @Environment(\.dismiss) for reliable dismissal and keeps
/// the close button in a single toolbar scope.
struct RoundDetailCover: View {

    let roundId: String
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RoundDetailView(viewModel: container.makeRoundDetailViewModel(roundId: roundId))
                .environmentObject(container)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColorsV3.textPrimary)
                        }
                    }
                }
        }
    }
}
