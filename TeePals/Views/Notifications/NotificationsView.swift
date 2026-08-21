import SwiftUI

/// V3 Notifications tab view - shows activity notifications with real-time updates.
/// Supports loading, empty, error states per UI_RULES.md.
struct NotificationsView: View {

    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @ObservedObject var viewModel: NotificationsViewModel

    @State private var roundDetail: RoundDetailIdentifier?
    @State private var selectedPostId: String?
    @State private var selectedProfileUid: String?
    @State private var selectedFeedbackRoundId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColorsV3.surfaceLight
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
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(AppColorsV3.textPrimary)
                        }
                    }
                }
            }
            .fullScreenCover(item: $roundDetail) { item in
                RoundDetailCover(roundId: item.roundId)
                    .environmentObject(container)
            }
            .navigationDestination(item: $selectedPostId) { postId in
                PostDetailView(
                    viewModel: container.makePostDetailViewModel(postId: postId),
                    onDeleted: { _ in
                        selectedPostId = nil
                    },
                    onUpdated: { _ in }
                )
            }
            .fullScreenCover(item: $selectedProfileUid) { uid in
                ProfileViewV3(viewModel: container.makeProfileViewModel(uid: uid), isPresented: true)
                    .environmentObject(container)
            }
            .sheet(item: $selectedFeedbackRoundId) { roundId in
                PostRoundFeedbackView(
                    viewModel: container.makePostRoundFeedbackViewModel(roundId: roundId)
                )
                .id(roundId)
            }
        }
    }
    
    // MARK: - Loading State

    private var loadingState: some View {
        ScrollView {
            SkeletonList(count: 6)
                .padding(AppSpacingV3.contentPadding)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            EmptyStateView.noNotifications
                .padding(.top, AppSpacingV3.xxl)
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        ScrollView {
            VStack {
                Spacer(minLength: AppSpacingV3.xxl)

                InlineErrorBanner(message, actionTitle: "Retry") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)

                Spacer()
            }
        }
    }

    // MARK: - Notifications Content

    private var notificationsContent: some View {
        ScrollView {
            // No horizontal padding on LazyVStack — headers must span full width when pinned.
            // Horizontal padding is applied per-item instead.
            LazyVStack(spacing: AppSpacingV3.lg, pinnedViews: [.sectionHeaders]) {
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
                                        .tint(AppColorsV3.forestGreen)
                                    }
                                }

                                if notification.id != notifications.last?.id {
                                    Divider()
                                        .background(AppColorsV3.borderLight)
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .background(AppColorsV3.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium)
                                .stroke(AppColorsV3.borderLight, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, AppSpacingV3.contentPadding)
                    } header: {
                        // Full-width background so content doesn't bleed through on either side when pinned.
                        HStack {
                            Text(section)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColorsV3.textSecondary)
                                .textCase(.uppercase)
                                .tracking(0.15 * 11)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacingV3.contentPadding)
                        .padding(.top, AppSpacingV3.md)
                        .padding(.bottom, AppSpacingV3.xs)
                        .frame(maxWidth: .infinity)
                        .background(AppColorsV3.surfaceLight)
                    }
                }

                // Load more button (only show if we have 20+ notifications)
                if viewModel.allNotifications.count >= 20 && viewModel.hasMoreNotifications {
                    loadMoreButton
                        .padding(.horizontal, AppSpacingV3.contentPadding)
                }
            }
            .padding(.vertical, AppSpacingV3.contentPadding)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var loadMoreButton: some View {
        Group {
            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(AppColorsV3.forestGreen)
                    .padding(.vertical, AppSpacingV3.md)
            } else {
                Button {
                    Task {
                        await viewModel.loadOlderNotifications()
                    }
                } label: {
                    Text("Load More")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColorsV3.forestGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacingV3.md)
                        .background(AppColorsV3.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacingV3.radiusMedium)
                                .stroke(AppColorsV3.borderLight, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    // MARK: - Navigation Handling

    /// Called when the user taps a notification row in the list.
    private func handleNotificationTap(_ notification: Notification) {
        print("Notification tapped — type: \(notification.type.rawValue), targetType: \(notification.targetType?.rawValue ?? "nil"), targetId: \(notification.targetId ?? "nil")")

        Task {
            await viewModel.markAsRead(notification)
        }

        routeNotification(
            type: notification.type.rawValue,
            targetId: notification.targetId ?? "",
            targetType: notification.targetType?.rawValue,
            metadata: notification.metadata
        )
    }

    /// Routes to the correct screen based on notification type and target.
    /// Push taps simply switch to this tab — the user taps the row to trigger this.
    private func routeNotification(
        type: String,
        targetId: String,
        targetType: String?,
        metadata: [String: String]?
    ) {
        guard !targetId.isEmpty else {
            print("Notification has no targetId — cannot navigate.")
            return
        }

        switch type {
        case NotificationType.roundInvitation.rawValue:
            deepLinkCoordinator.navigateToActivityTab(.invites)

        case NotificationType.feedbackReminder.rawValue:
            selectedFeedbackRoundId = targetId

        default:
            switch targetType {
            case TargetType.round.rawValue:
                roundDetail = RoundDetailIdentifier(roundId: targetId)
            case TargetType.post.rawValue:
                selectedPostId = targetId
            case TargetType.comment.rawValue:
                if let postId = metadata?["postId"] {
                    selectedPostId = postId
                }
            case TargetType.profile.rawValue:
                selectedProfileUid = targetId
            default:
                print("Unknown notification target — type: \(type), targetType: \(targetType ?? "nil")")
            }
        }
    }
}

// MARK: - Notification Row View (V3)

struct NotificationRowView: View {
    let notification: Notification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar for unread
                if !notification.isRead {
                    Rectangle()
                        .fill(AppColorsV3.forestGreen)
                        .frame(width: 4)
                }

                HStack(alignment: .top, spacing: AppSpacingV3.md) {
                    // Bell icon - forest green when unread, grey when read
                    ZStack {
                        Circle()
                            .fill(notification.isRead ? Color(hex: "F3F4F6") : AppColorsV3.forestGreen.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: "bell.fill")
                            .font(.system(size: 18, weight: notification.isRead ? .regular : .semibold))
                            .foregroundColor(notification.isRead ? AppColorsV3.textSecondary : AppColorsV3.forestGreen)
                    }

                    // Content - takes up remaining space
                    VStack(alignment: .leading, spacing: AppSpacingV3.xs) {
                        // Category label - more prominent when unread
                        Text(categoryLabel)
                            .font(.system(size: 11, weight: notification.isRead ? .medium : .bold))
                            .foregroundColor(notification.isRead ? AppColorsV3.textTertiary : AppColorsV3.forestGreen)
                            .textCase(.uppercase)
                            .tracking(0.15 * 11)

                        // Body
                        Text(notification.body)
                            .font(.system(size: 15, weight: notification.isRead ? .regular : .medium))
                            .foregroundColor(notification.isRead ? AppColorsV3.textSecondary : AppColorsV3.textPrimary)
                            .lineLimit(3)

                        // Time ago
                        Text(notification.timeAgoString)
                            .font(.system(size: 12))
                            .foregroundColor(AppColorsV3.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacingV3.md)
                .padding(.vertical, AppSpacingV3.md)
            }
            .background(notification.isRead
                ? AppColorsV3.surfaceWhite
                : AppColorsV3.forestGreen.opacity(0.04)
            )
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
            .environmentObject(DeepLinkCoordinator())
    }
}
#endif
