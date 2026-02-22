import SwiftUI

// MARK: - Comment Row View

/// Displays a single comment with nested replies, likes, and actions.
/// Handles main comment display, reply threading, and user interactions.
struct CommentRowView: View {
    let comment: Comment
    let currentUserUid: String?
    let postAuthorUid: String
    let onReply: (Comment) -> Void
    let onLike: (Comment) -> Void
    let onDelete: () -> Void
    let onDeleteReply: (Comment) -> Void
    let onAuthorTap: (String) -> Void

    @State private var showDeleteConfirmation = false
    @State private var showReplies = true
    @State private var replyToDelete: Comment?

    private var replyCount: Int {
        comment.replies?.count ?? 0
    }

    private var isPostAuthor: Bool {
        comment.authorUid == postAuthorUid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main comment
            mainCommentView

            // Nested replies with toggle
            if replyCount > 0 {
                repliesSection
            }
        }
        .alert("Delete Comment?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Reply?", isPresented: .constant(replyToDelete != nil)) {
            Button("Delete", role: .destructive) {
                if let reply = replyToDelete {
                    onDeleteReply(reply)
                    replyToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                replyToDelete = nil
            }
        }
    }

    // MARK: - Main Comment

    private var mainCommentView: some View {
        let isAuthor = comment.authorUid == currentUserUid

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header with author info
            HStack(spacing: AppSpacing.sm) {
                if comment.isSoftDeleted {
                    // Deleted comment: generic avatar (not tappable)
                    Circle()
                        .fill(AppColors.textTertiary.opacity(0.3))
                        .frame(width: 32, height: 32)

                    // Deleted user label
                    Text("Deleted User")
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.textTertiary)
                } else {
                    // Avatar (tappable)
                    Button {
                        onAuthorTap(comment.authorUid)
                    } label: {
                        avatarView(c: comment, size: 32)
                    }
                    .buttonStyle(.plain)

                    // Author name with red dot if post author
                    HStack(spacing: 4) {
                        Button {
                            onAuthorTap(comment.authorUid)
                        } label: {
                            Text(comment.authorNickname ?? "Unknown")
                                .font(AppTypography.labelMedium)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .buttonStyle(.plain)

                        if isPostAuthor {
                            Text("*")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.error)
                        }
                    }
                }

                Spacer()
            }

            // Comment text
            Text(comment.displayText)
                .font(AppTypography.bodyMedium)
                .foregroundColor(comment.isSoftDeleted ? AppColors.textTertiary : AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AppSpacing.sm)

            // Footer: time, like, reply, menu (hide actions for deleted comments)
            HStack(spacing: AppSpacing.lg) {
                Text(comment.timeAgoString)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textTertiary)

                if !comment.isSoftDeleted {

                Button {
                    onLike(comment)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: (comment.hasLiked ?? false) ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor((comment.hasLiked ?? false) ? AppColors.error : AppColors.textSecondary)

                        if let likeCount = comment.likeCount, likeCount > 0 {
                            Text("\(likeCount)")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text("Like")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Button {
                    onReply(comment)
                } label: {
                    Text("Reply")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Three dots menu - always visible
                Menu {
                    if isAuthor {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    Button {
                        // TODO: Implement report
                    } label: {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textTertiary)
                        .frame(width: 44)  // Only expand width, let height be natural
                }
                }

                Spacer()
            }
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.contentPadding)
    }

    // MARK: - Replies Section

    private var repliesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Replies list
            if let replies = comment.replies {
                ForEach(replies) { reply in
                    replyView(reply)

                    // Separator between replies
                    if reply.id != replies.last?.id {
                        Rectangle()
                            .fill(AppColors.textTertiary.opacity(0.15))
                            .frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - Reply View (nested comment)

    private func replyView(_ reply: Comment) -> some View {
        let isReplyPostAuthor = reply.authorUid == postAuthorUid
        let isReplyAuthor = reply.authorUid == currentUserUid

        return ZStack {
            // Grey background filling full width
            AppColors.backgroundSecondary.opacity(0.7)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Header with author info
                HStack(spacing: AppSpacing.sm) {
                    // Avatar (tappable)
                    Button {
                        onAuthorTap(reply.authorUid)
                    } label: {
                        avatarView(c: reply, size: 32)
                    }
                    .buttonStyle(.plain)

                    // Author name with red dot if post author
                    HStack(spacing: 4) {
                        Button {
                            onAuthorTap(reply.authorUid)
                        } label: {
                            Text(reply.authorNickname ?? "Unknown")
                                .font(AppTypography.labelMedium)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .buttonStyle(.plain)

                        if isReplyPostAuthor {
                            Text("*")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.error)
                        }
                    }

                    Spacer()
                }

                // Reply text
                Text(reply.displayText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, AppSpacing.sm)

                // Footer: time, like, reply, menu
                HStack(spacing: AppSpacing.lg) {
                    Text(reply.timeAgoString)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)

                    Button {
                        onLike(reply)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: (reply.hasLiked ?? false) ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor((reply.hasLiked ?? false) ? AppColors.error : AppColors.textSecondary)

                            if let likeCount = reply.likeCount, likeCount > 0 {
                                Text("\(likeCount)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text("Like")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    Button {
                        onReply(reply)
                    } label: {
                        Text("Reply")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Three dots menu - always visible
                    Menu {
                        if isReplyAuthor {
                            Button(role: .destructive) {
                                replyToDelete = reply
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        Button {
                            // TODO: Implement report
                        } label: {
                            Label("Report", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 44)  // Only expand width, let height be natural
                    }

                    Spacer()
                }
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.leading, AppSpacing.contentPadding + AppSpacing.lg)
            .padding(.trailing, AppSpacing.contentPadding)
        }
    }

    // MARK: - Avatar Helper

    private func avatarView(c: Comment, size: CGFloat) -> some View {
        TPAvatar(
            url: c.authorPhotoUrl.flatMap { URL(string: $0) },
            size: size
        )
    }
}
