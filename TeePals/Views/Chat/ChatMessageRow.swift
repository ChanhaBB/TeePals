import SwiftUI

/// Individual chat message row with sender info and state indicators.
struct ChatMessageRow: View {

    let message: ChatMessage
    let isOwnMessage: Bool
    let showTimestamp: Bool
    let showSenderInfo: Bool  // For grouping consecutive messages
    let senderPhotoUrl: String?
    let onRetry: () -> Void
    let onPhotoTap: (String) -> Void
    let onAuthorTap: (String) -> Void
    
    var body: some View {
        if message.isSystemMessage {
            systemMessageView
        } else {
            userMessageView
        }
    }
    
    // MARK: - System Message
    
    private var systemMessageView: some View {
        HStack {
            Spacer()
            
            Text(message.text)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
                .italic()
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.backgroundSecondary.opacity(0.5))
                .cornerRadius(AppSpacing.radiusSmall)
            
            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }
    
    // MARK: - User Message
    
    private var userMessageView: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            if isOwnMessage {
                Spacer(minLength: 60)
                ownMessageBubble
            } else {
                otherMessageBubble
                Spacer(minLength: 60)
            }
        }
    }
    
    // MARK: - Own Message (Right Side)

    private var ownMessageBubble: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .trailing, spacing: 4) {
                // Sender name (only on first message in group)
                if showSenderInfo {
                    Text(message.senderNickname ?? "You")
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Photo (if present)
                if let photoUrl = message.photoUrl {
                    photoView(url: photoUrl)
                }

                // Message bubble (only if text present)
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.primary)
                        .cornerRadius(AppSpacing.radiusMedium)
                }

                // Status row (only show if timestamp visible or not sent yet)
                if showTimestamp || message.sendState != .sent {
                    HStack(spacing: 4) {
                        if showTimestamp {
                            Text(message.displayTime)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        statusIndicator
                    }
                }
            }

            // Avatar (visible or spacer for alignment)
            if showSenderInfo {
                avatarView
            } else {
                // Invisible spacer to maintain alignment
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }
    
    // MARK: - Other Message (Left Side)
    
    private var otherMessageBubble: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Avatar (visible or spacer for alignment) - tappable
            if showSenderInfo {
                Button {
                    onAuthorTap(message.senderUid)
                } label: {
                    avatarView
                }
                .buttonStyle(.plain)
            } else {
                // Invisible spacer to maintain alignment
                Color.clear.frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Sender name (only on first message in group) - tappable
                if showSenderInfo {
                    Button {
                        onAuthorTap(message.senderUid)
                    } label: {
                        Text(message.senderNickname ?? "Unknown")
                            .font(AppTypography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Photo (if present)
                if let photoUrl = message.photoUrl {
                    photoView(url: photoUrl)
                }

                // Message bubble (only if text present)
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.backgroundPrimary)
                        .cornerRadius(AppSpacing.radiusMedium)
                }

                // Time (only if timestamp should be shown)
                if showTimestamp {
                    Text(message.displayTime)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }
    
    // MARK: - Avatar View
    
    private var avatarView: some View {
        TPAvatar(
            url: senderPhotoUrl.flatMap { URL(string: $0) },
            size: 32
        )
    }
    
    private var initialsAvatar: some View {
        Circle()
            .fill(AppColors.backgroundSecondary)
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(message.senderNickname?.prefix(1) ?? "?"))
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textSecondary)
            )
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch message.sendState {
        case .sending:
            ProgressView()
                .scaleEffect(0.6)
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
        case .failed:
            Button {
                onRetry()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Tap to retry")
                        .font(AppTypography.caption)
                }
                .foregroundColor(AppColors.error)
            }
        }
    }

    // MARK: - Photo View

    private func photoView(url: String) -> some View {
        Button {
            onPhotoTap(url)
        } label: {
            TPImage(url: URL(string: url))
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct ChatMessageRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.sm) {
            // First message from Sarah (shows avatar)
            ChatMessageRow(
                message: ChatMessage(
                    id: "1",
                    roundId: "round1",
                    senderUid: "user2",
                    text: "Hey everyone!",
                    senderNickname: "Sarah"
                ),
                isOwnMessage: false,
                showTimestamp: false,
                showSenderInfo: true,
                senderPhotoUrl: nil,
                onRetry: {},
                onPhotoTap: { _ in },
                onAuthorTap: { _ in }
            )

            // Second message from Sarah (grouped - no avatar)
            ChatMessageRow(
                message: ChatMessage(
                    id: "2",
                    roundId: "round1",
                    senderUid: "user2",
                    text: "See you at the clubhouse.",
                    senderNickname: "Sarah"
                ),
                isOwnMessage: false,
                showTimestamp: true,
                showSenderInfo: false,
                senderPhotoUrl: nil,
                onRetry: {},
                onPhotoTap: { _ in },
                onAuthorTap: { _ in }
            )

            // Own message
            ChatMessageRow(
                message: ChatMessage(
                    id: "3",
                    roundId: "round1",
                    senderUid: "user1",
                    text: "Sounds good!",
                    senderNickname: "John"
                ),
                isOwnMessage: true,
                showTimestamp: true,
                showSenderInfo: true,
                senderPhotoUrl: nil,
                onRetry: {},
                onPhotoTap: { _ in },
                onAuthorTap: { _ in }
            )
        }
        .padding()
        .background(AppColors.backgroundGrouped)
    }
}
#endif

