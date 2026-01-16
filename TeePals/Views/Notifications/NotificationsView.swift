import SwiftUI

/// Notifications tab view - shows activity notifications with real-time updates.
/// Supports loading, empty, error states per UI_RULES.md.
struct NotificationsView: View {

    @EnvironmentObject var container: AppContainer
    @ObservedObject var viewModel: NotificationsViewModel

    @State private var selectedRoundId: String?
    @State private var selectedPostId: String?
    @State private var selectedProfileUid: String?
    @State private var selectedFeedbackRoundId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background that extends under nav bar
                AppColors.backgroundGrouped
                    .ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.isEmpty {
                        loadingState
                    } else if let error = viewModel.errorMessage {
                        errorState(error)
                    } else if viewModel.isEmpty {
                        emptyState
                    } else {
                        notificationsContent
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.isEmpty && viewModel.unreadCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                Task {
                                    await viewModel.markAllAsRead()
                                }
                            } label: {
                                Label("Mark All as Read", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedRoundId) { roundId in
                RoundDetailView(viewModel: container.makeRoundDetailViewModel(roundId: roundId))
            }
            .navigationDestination(item: $selectedPostId) { postId in
                PostDetailView(
                    viewModel: container.makePostDetailViewModel(postId: postId),
                    onDeleted: { _ in
                        // Post deleted - no action needed in notifications view
                        selectedPostId = nil
                    },
                    onUpdated: { _ in
                        // Post updated - no action needed
                    }
                )
            }
            .sheet(item: $selectedProfileUid) { uid in
                OtherUserProfileView(viewModel: container.makeOtherUserProfileViewModel(uid: uid))
            }
            .sheet(item: $selectedFeedbackRoundId) { roundId in
                PostRoundFeedbackView(
                    viewModel: container.makePostRoundFeedbackViewModel(roundId: roundId)
                )
            }
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        ScrollView {
            SkeletonList(count: 6)
                .padding(AppSpacing.contentPadding)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView {
            EmptyStateView.noNotifications
                .padding(.top, AppSpacing.xxl)
        }
    }
    
    // MARK: - Error State
    
    private func errorState(_ message: String) -> some View {
        ScrollView {
            VStack {
                Spacer(minLength: AppSpacing.xxl)

                InlineErrorBanner(message, actionTitle: "Retry") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .padding(.horizontal, AppSpacing.contentPadding)

                Spacer()
            }
        }
    }

    // MARK: - Notifications Content

    private var notificationsContent: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.groupedNotifications, id: \.0) { section, notifications in
                    Section {
                        LazyVStack(spacing: 0) {
                            ForEach(notifications) { notification in
                                NotificationRowView(notification: notification) {
                                    handleNotificationTap(notification)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteNotification(notification)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    if !notification.isRead {
                                        Button {
                                            Task {
                                                await viewModel.markAsRead(notification)
                                            }
                                        } label: {
                                            Label("Mark Read", systemImage: "checkmark.circle")
                                        }
                                        .tint(.blue)
                                    }
                                }

                                if notification.id != notifications.last?.id {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .background(AppColors.surface)
                        .cornerRadius(AppSpacing.radiusLarge)
                    } header: {
                        HStack {
                            Text(section)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.contentPadding)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.xs)
                        .background(AppColors.backgroundGrouped)
                    }
                }

                // Load more button (only show if we have 20+ notifications)
                if viewModel.allNotifications.count >= 20 && viewModel.hasMoreNotifications {
                    loadMoreButton
                }
            }
            .padding(AppSpacing.contentPadding)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var loadMoreButton: some View {
        Group {
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.vertical, AppSpacing.md)
            } else {
                Button {
                    Task {
                        await viewModel.loadOlderNotifications()
                    }
                } label: {
                    Text("Load More")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(AppSpacing.radiusMedium)
                }
            }
        }
    }

    // MARK: - Navigation Handling

    private func handleNotificationTap(_ notification: Notification) {
        // Mark as read (ViewModel handles both notification and chat unread counts)
        Task {
            await viewModel.markAsRead(notification)
        }

        // Handle feedback reminders specially - open feedback view
        if notification.type == .feedbackReminder {
            if let roundId = notification.targetId {
                selectedFeedbackRoundId = roundId
            }
            return
        }

        // Navigate based on notification type
        guard let targetId = notification.targetId else { return }

        switch notification.targetType {
        case .round:
            navigateToRound(targetId)
        case .post:
            navigateToPost(targetId)
        case .comment:
            if let postId = notification.metadata?["postId"] {
                navigateToPost(postId)
            }
        case .profile:
            navigateToProfile(targetId)
        case .none:
            break
        }
    }

    private func navigateToRound(_ roundId: String) {
        selectedRoundId = roundId
    }

    private func navigateToPost(_ postId: String) {
        selectedPostId = postId
    }

    private func navigateToProfile(_ uid: String) {
        selectedProfileUid = uid
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let notification: Notification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar for unread
                if !notification.isRead {
                    Rectangle()
                        .fill(AppColors.iconAccent)
                        .frame(width: 4)
                }

                HStack(alignment: .top, spacing: AppSpacing.md) {
                    // Bell icon - red when unread, grey when read
                    ZStack {
                        Circle()
                            .fill(notification.isRead ? AppColors.surfaceSecondary : AppColors.iconAccent.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: "bell.fill")
                            .font(.system(size: 18, weight: notification.isRead ? .regular : .semibold))
                            .foregroundColor(notification.isRead ? AppColors.textSecondary : AppColors.iconAccent)
                    }

                    // Content - takes up remaining space
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        // Category label - more prominent when unread
                        Text(categoryLabel)
                            .font(notification.isRead ? AppTypography.caption : AppTypography.captionEmphasis)
                            .foregroundColor(notification.isRead ? AppColors.textTertiary : AppColors.iconAccent)
                            .fontWeight(notification.isRead ? .regular : .semibold)

                        // Body
                        Text(notification.body)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(notification.isRead ? AppColors.textSecondary : AppColors.textPrimary)
                            .fontWeight(notification.isRead ? .regular : .medium)
                            .lineLimit(3)

                        // Time ago
                        Text(notification.timeAgoString)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
            }
            .background(notification.isRead ? AppColors.surface : Color.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Helper

    private var categoryLabel: String {
        switch notification.type {
        // Rounds category
        case .roundJoinRequest, .roundJoinAccepted, .roundJoinDeclined,
             .roundInvitation, .roundCancelled, .roundUpdated:
            return "Rounds"

        // Chat category
        case .roundChatMessage:
            return "Chat"

        // Social category
        case .userFollowed, .postUpvoted, .postCommented, .commentReplied, .commentMentioned:
            return "Social"

        // System category
        case .welcomeMessage, .tier2Reminder, .roundReminder, .feedbackReminder:
            return "System"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        NotificationsView(viewModel: container.makeNotificationsViewModel())
            .environmentObject(container)
    }
}
#endif
