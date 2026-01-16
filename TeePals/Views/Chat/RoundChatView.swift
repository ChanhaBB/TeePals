import SwiftUI
import PhotosUI

/// Round group chat view with real-time messages.
struct RoundChatView: View {

    @StateObject private var viewModel: RoundChatViewModel
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var showPhotoViewer = false
    @State private var photoViewerUrl: String?
    @State private var selectedAuthorUid: String?

    init(viewModel: RoundChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat header with round info
            if let round = viewModel.round {
                chatHeader(round)
            }
            
            Divider()
            
            // Messages area fills remaining space
            messagesArea
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerBar
        }
        .navigationTitle("Round Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadChat()
        }
        .onChange(of: viewModel.selectedPhoto) {
            Task { await viewModel.loadPhoto() }
        }
        .sheet(isPresented: $showPhotoViewer) {
            if let url = photoViewerUrl {
                PhotoViewerView(photoUrls: [url], initialIndex: 0)
            }
        }
        .sheet(item: Binding(
            get: { selectedAuthorUid.map { IdentifiableString(value: $0) } },
            set: { selectedAuthorUid = $0?.value }
        )) { wrapper in
            if wrapper.value == viewModel.uid {
                // Show own profile
                NavigationStack {
                    ProfileView(viewModel: container.makeProfileViewModel())
                }
            } else {
                // Show other user's profile
                NavigationStack {
                    OtherUserProfileView(
                        viewModel: container.makeOtherUserProfileViewModel(uid: wrapper.value)
                    )
                }
            }
        }
        .overlay {
            if viewModel.isUploadingPhoto {
                uploadingOverlay
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Composer Bar

    private var composerBar: some View {
        VStack(spacing: 0) {
            // Photo preview (if selected)
            if let photoImage = viewModel.photoImage {
                photoPreviewBar(image: photoImage)
            }

            Divider()

            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                // Photo picker button
                photoPickerButton

                // Text field
                textField

                // Send button
                sendButton
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.backgroundPrimary)
    }
    
    // MARK: - Header
    
    private func chatHeader(_ round: Round) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "flag.fill")
                .foregroundColor(AppColors.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(round.displayCourseName)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                if let dateTime = round.displayDateTime {
                    Text(dateTime)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            // Members count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                Text("\(round.acceptedCount)/\(round.maxPlayers)")
                    .font(AppTypography.caption)
            }
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundPrimary)
    }
    
    // MARK: - Messages Area
    
    @ViewBuilder
    private var messagesArea: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.messages.isEmpty {
            emptyStateView
        } else {
            messagesList
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundGrouped)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(AppColors.primary.opacity(0.4))
            
            Text("No messages yet")
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            if viewModel.canSendMessages {
                Text("Say hi to coordinate logistics!")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text("You'll get chat access once accepted.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundGrouped)
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.sm) {
                    // Load more button
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                    }

                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.clientNonce) { index, message in
                        // Date separator if needed
                        if shouldShowDateSeparator(at: index) {
                            ChatDateSeparator(date: message.createdAt)
                        }

                        ChatMessageRow(
                            message: message,
                            isOwnMessage: viewModel.isOwnMessage(message),
                            showTimestamp: shouldShowTimestamp(at: index),
                            showSenderInfo: shouldShowSenderInfo(at: index),
                            senderPhotoUrl: viewModel.senderPhotoUrl(for: message.senderUid),
                            onRetry: { Task { await viewModel.retryMessage(message) } },
                            onPhotoTap: { url in
                                photoViewerUrl = url
                                showPhotoViewer = true
                            },
                            onAuthorTap: { uid in
                                selectedAuthorUid = uid
                            }
                        )
                        .id(message.clientNonce)
                    }
                }
                .padding(AppSpacing.md)
                .id(viewModel.senderProfiles.count) // Force re-render when profiles load
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.backgroundGrouped)
            .onChange(of: viewModel.messages.count) { _, _ in
                // Scroll to bottom on new messages
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.clientNonce, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Scroll to bottom initially
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.clientNonce, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Timestamp Logic
    
    /// Show timestamp if: last message, or 5+ minute gap to next message
    private func shouldShowTimestamp(at index: Int) -> Bool {
        let messages = viewModel.messages
        
        // Always show on last message
        if index == messages.count - 1 {
            return true
        }
        
        // Show if 5+ minute gap to next message
        let current = messages[index]
        let next = messages[index + 1]
        let gap = next.createdAt.timeIntervalSince(current.createdAt)
        return gap >= 5 * 60 // 5 minutes
    }
    
    /// Show date separator if first message or different day from previous
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        let messages = viewModel.messages
        
        // Always show for first message
        if index == 0 {
            return true
        }
        
        // Show if different day from previous message
        let current = messages[index]
        let previous = messages[index - 1]
        return !Calendar.current.isDate(current.createdAt, inSameDayAs: previous.createdAt)
    }
    
    /// Show sender info (avatar + name) only for first message in a group
    /// Messages are grouped if: same sender AND within 5 minutes
    private func shouldShowSenderInfo(at index: Int) -> Bool {
        let messages = viewModel.messages
        let current = messages[index]

        // System messages don't show sender info
        if current.isSystemMessage { return false }

        // Find previous non-system message to compare against
        var previousIndex = index - 1
        while previousIndex >= 0 && messages[previousIndex].isSystemMessage {
            previousIndex -= 1
        }

        // If no previous non-system message, this is the first real message - show info
        if previousIndex < 0 { return true }

        // If date separator shown, show sender info
        if shouldShowDateSeparator(at: index) { return true }

        let previousMessage = messages[previousIndex]

        // Different sender = show info
        if previousMessage.senderUid != current.senderUid { return true }

        // Same sender but > 5 min gap = show info
        let gap = current.createdAt.timeIntervalSince(previousMessage.createdAt)
        if gap >= 5 * 60 { return true }

        // Same sender within 5 min = hide info (grouped)
        return false
    }

    // MARK: - Photo Components

    private func photoPreviewBar(image: UIImage) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Photo thumbnail
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))

            Spacer()

            // Remove button
            Button {
                viewModel.removePhoto()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
    }

    private var photoPickerButton: some View {
        let canSend = viewModel.canSendMessages
        return PhotosPicker(
            selection: $viewModel.selectedPhoto,
            matching: .images
        ) {
            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundColor(
                    canSend
                    ? AppColors.primary
                    : AppColors.textTertiary
                )
        }
        .disabled(!canSend)
    }

    private var textField: some View {
        TextField(
            viewModel.canSendMessages ? "Type a message..." : "Chat access required",
            text: $viewModel.composerText,
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(AppTypography.bodyMedium)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .lineLimit(1...5)
        .disabled(!viewModel.canSendMessages)
        .opacity(viewModel.canSendMessages ? 1.0 : 0.6)
    }

    private var sendButton: some View {
        Button {
            Task { await viewModel.sendMessage() }
        } label: {
            ZStack {
                if viewModel.isSending {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
            }
            .foregroundColor(
                viewModel.isComposerEnabled
                ? AppColors.primary
                : AppColors.textTertiary
            )
        }
        .disabled(!viewModel.isComposerEnabled)
    }

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.md) {
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text("Uploading photo...")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(.white)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.md)
        }
    }
}

// MARK: - Identifiable String Wrapper

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

