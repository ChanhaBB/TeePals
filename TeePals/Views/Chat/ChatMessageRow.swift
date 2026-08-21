import SwiftUI

/// V3 Individual chat message row with sender info and state indicators.
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
                .font(.system(size: 12))
                .foregroundColor(AppColorsV3.textSecondary)
                .italic()
                .padding(.horizontal, AppSpacingV3.md)
                .padding(.vertical, AppSpacingV3.xs)
                .background(Color(hex: "F3F4F6").opacity(0.5))
                .cornerRadius(AppSpacingV3.radiusSmall)

            Spacer()
        }
        .padding(.vertical, AppSpacingV3.xs)
    }
    
    // MARK: - User Message
    
    private var userMessageView: some View {
        HStack(alignment: .bottom, spacing: AppSpacingV3.xs) {
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
        HStack(alignment: .top, spacing: AppSpacingV3.sm) {
            VStack(alignment: .trailing, spacing: 4) {
                // Photo (if present)
                if let photoUrl = message.photoUrl {
                    photoView(url: photoUrl)
                }

                // Message bubble (only if text present)
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacingV3.md)
                        .padding(.vertical, 12)
                        .background(AppColorsV3.forestGreen)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 4, // Sharp bottom-right
                                topTrailingRadius: 16
                            )
                        )
                }

                // Status row (only show if timestamp visible or not sent yet)
                if showTimestamp || message.sendState != .sent {
                    HStack(spacing: 4) {
                        if showTimestamp {
                            Text(message.displayTime)
                                .font(.system(size: 10))
                                .foregroundColor(Color.gray.opacity(0.5))
                        }
                        statusIndicator
                    }
                    .padding(.trailing, 4)
                }
            }

            // Avatar (visible or spacer for alignment)
            if showSenderInfo {
                avatarView
            } else {
                // Invisible spacer to maintain alignment
                Color.clear.frame(width: 26, height: 26)
            }
        }
    }
    
    // MARK: - Other Message (Left Side)
    
    private var otherMessageBubble: some View {
        HStack(alignment: .top, spacing: AppSpacingV3.sm) {
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
                Color.clear.frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Sender name (only on first message in group) - tappable
                if showSenderInfo {
                    HStack(spacing: 8) {
                        Button {
                            onAuthorTap(message.senderUid)
                        } label: {
                            Text(message.senderNickname ?? "Unknown")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColorsV3.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 4)
                }

                // Photo (if present)
                if let photoUrl = message.photoUrl {
                    photoView(url: photoUrl)
                }

                // Message bubble (only if text present)
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 14))
                        .foregroundColor(AppColorsV3.textPrimary)
                        .padding(.horizontal, AppSpacingV3.md)
                        .padding(.vertical, 12)
                        .background(Color(hex: "F3F4F6")) // Bubble gray from HTML
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 4, // Sharp top-left
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 16
                            )
                        )
                }

                // Time (only if timestamp should be shown)
                if showTimestamp {
                    Text(message.displayTime)
                        .font(.system(size: 10))
                        .foregroundColor(Color.gray.opacity(0.5))
                        .padding(.leading, 4)
                }
            }
        }
    }
    
    // MARK: - Avatar View

    private var avatarView: some View {
        TPAvatar(
            url: senderPhotoUrl.flatMap { URL(string: $0) },
            size: 26
        )
    }

    private var initialsAvatar: some View {
        Circle()
            .fill(Color(hex: "F3F4F6"))
            .frame(width: 26, height: 26)
            .overlay(
                Text(String(message.senderNickname?.prefix(1) ?? "?"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColorsV3.textSecondary)
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
                .foregroundColor(Color.gray.opacity(0.5))
        case .failed:
            Button {
                onRetry()
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Tap to retry")
                        .font(.system(size: 11))
                }
                .foregroundColor(AppColorsV3.error)
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
                .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct ChatMessageRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacingV3.xs) {
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
        .background(AppColorsV3.surfaceLight)
    }
}
#endif

