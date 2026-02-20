import SwiftUI

/// Generic wrapper that handles the four standard UI states:
/// loading, error, empty, and content.
///
/// Usage:
/// ```
/// AsyncContentView(
///     isLoading: viewModel.isLoading,
///     errorMessage: viewModel.errorMessage,
///     isEmpty: viewModel.items.isEmpty,
///     onRetry: { await viewModel.load() },
///     loading: { SkeletonList(count: 5) },
///     empty: { EmptyStateView.noRounds(onCreate: { }) },
///     content: { ForEach(viewModel.items) { ... } }
/// )
/// ```
struct AsyncContentView<Loading: View, Empty: View, Content: View>: View {

    let isLoading: Bool
    let errorMessage: String?
    let isEmpty: Bool
    let onRetry: (() async -> Void)?

    @ViewBuilder let loading: () -> Loading
    @ViewBuilder let empty: () -> Empty
    @ViewBuilder let content: () -> Content

    init(
        isLoading: Bool,
        errorMessage: String? = nil,
        isEmpty: Bool,
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder empty: @escaping () -> Empty,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.isEmpty = isEmpty
        self.onRetry = onRetry
        self.loading = loading
        self.empty = empty
        self.content = content
    }

    var body: some View {
        Group {
            if isLoading && isEmpty {
                loading()
            } else if let error = errorMessage {
                errorState(error)
            } else if isEmpty {
                empty()
            } else {
                content()
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            InlineErrorBanner(
                message,
                actionTitle: onRetry != nil ? "Retry" : nil,
                action: onRetry.map { retry in
                    { Task { await retry() } }
                }
            )
            .padding(.horizontal, AppSpacing.contentPadding)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Convenience initializer (default SkeletonList loading)

extension AsyncContentView where Loading == SkeletonList {

    init(
        isLoading: Bool,
        errorMessage: String? = nil,
        isEmpty: Bool,
        skeletonCount: Int = 5,
        onRetry: (() async -> Void)? = nil,
        @ViewBuilder empty: @escaping () -> Empty,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isLoading: isLoading,
            errorMessage: errorMessage,
            isEmpty: isEmpty,
            onRetry: onRetry,
            loading: { SkeletonList(count: skeletonCount) },
            empty: empty,
            content: content
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AsyncContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AsyncContentView(
                isLoading: true,
                isEmpty: true,
                loading: { SkeletonList(count: 4) },
                empty: { EmptyStateView.noNotifications },
                content: { Text("Content") }
            )
            .previewDisplayName("Loading")

            AsyncContentView(
                isLoading: false,
                errorMessage: "Something went wrong.",
                isEmpty: true,
                onRetry: { },
                loading: { SkeletonList() },
                empty: { EmptyStateView.noNotifications },
                content: { Text("Content") }
            )
            .previewDisplayName("Error")

            AsyncContentView(
                isLoading: false,
                isEmpty: true,
                loading: { SkeletonList() },
                empty: { EmptyStateView.noNotifications },
                content: { Text("Content") }
            )
            .previewDisplayName("Empty")

            AsyncContentView(
                isLoading: false,
                isEmpty: false,
                loading: { SkeletonList() },
                empty: { EmptyStateView.noNotifications },
                content: {
                    VStack {
                        Text("Real content here")
                    }
                }
            )
            .previewDisplayName("Content")
        }
    }
}
#endif
