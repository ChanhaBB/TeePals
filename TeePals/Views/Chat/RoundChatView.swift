import SwiftUI
import PhotosUI

/// V3 Round group chat view with real-time messages.
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
            // V3 Sheet-style header
            if let round = viewModel.round {
                chatHeaderV3(round)
            }

            // Messages area fills remaining space
            messagesArea
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerBarV3
        }
        .background(AppColorsV3.surfaceWhite)
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
        .fullScreenCover(item: Binding(
            get: { selectedAuthorUid.map { IdentifiableString(value: $0) } },
            set: { selectedAuthorUid = $0?.value }
        )) { wrapper in
            ProfileViewV3(viewModel: container.makeProfileViewModel(uid: wrapper.value), isPresented: true)
                .environmentObject(container)
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
    
    // MARK: - V3 Header

    private func chatHeaderV3(_ round: Round) -> some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 48, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header content
            HStack(alignment: .top, spacing: AppSpacingV3.md) {
                // Course info
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.displayCourseName.compactCourseName())
                        .font(AppTypographyV3.sectionHeaderSerif)
                        .foregroundColor(AppColorsV3.forestGreen)
                        .lineLimit(1)

                    Text(headerSubtitle(round))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColorsV3.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Spacer()

                // Members count + close button
                HStack(spacing: AppSpacingV3.sm) {
                    // Members count
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                        Text("\(round.acceptedCount)/\(round.maxPlayers)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppColorsV3.textSecondary)

                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Circle()
                            .fill(AppColorsV3.borderLight)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColorsV3.textPrimary)
                            )
                    }
                }
            }
            .padding(.horizontal, AppSpacingV3.contentPadding)
            .padding(.bottom, AppSpacingV3.md)
        }
        .background(
            AppColorsV3.surfaceWhite
                .opacity(0.95)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .fill(AppColorsV3.borderLight)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func headerSubtitle(_ round: Round) -> String {
        var parts: [String] = []

        // Location
        parts.append(round.displayCityLabel)

        // Date
        if let date = round.displayTeeTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            parts.append(formatter.string(from: date))
        }

        // Time
        if let time = round.displayTeeTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            parts.append(formatter.string(from: time))
        }

        return parts.joined(separator: " • ")
    }

    // MARK: - V3 Composer Bar

    private var composerBarV3: some View {
        VStack(spacing: 0) {
            // Photo preview (if selected)
            if let photoImage = viewModel.photoImage {
                photoPreviewBarV3(image: photoImage)
            }

            Rectangle()
                .fill(AppColorsV3.borderLight)
                .frame(height: 1)

            HStack(alignment: .bottom, spacing: AppSpacingV3.sm) {
                // Photo picker button
                photoPickerButtonV3

                // Text field
                textFieldV3

                // Send button
                sendButtonV3
            }
            .padding(.horizontal, AppSpacingV3.md)
            .padding(.vertical, AppSpacingV3.sm)
            .background(AppColorsV3.surfaceWhite)
        }
    }

    private func photoPreviewBarV3(image: UIImage) -> some View {
        HStack(spacing: AppSpacingV3.sm) {
            // Photo thumbnail
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacingV3.radiusSmall))

            Spacer()

            // Remove button
            Button {
                viewModel.removePhoto()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColorsV3.textSecondary)
            }
        }
        .padding(AppSpacingV3.sm)
        .background(AppColorsV3.borderLight)
    }

    private var photoPickerButtonV3: some View {
        let canSend = viewModel.canSendMessages
        return PhotosPicker(
            selection: $viewModel.selectedPhoto,
            matching: .images
        ) {
            Circle()
                .fill(canSend ? AppColorsV3.borderLight : Color.clear)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(
                            canSend
                            ? AppColorsV3.forestGreen
                            : AppColorsV3.textSecondary.opacity(0.4)
                        )
                )
        }
        .disabled(!canSend)
    }

    private var textFieldV3: some View {
        TextField(
            viewModel.canSendMessages ? "Type a message..." : "Chat access required",
            text: $viewModel.composerText,
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(.system(size: 15))
        .foregroundColor(AppColorsV3.textPrimary)
        .padding(.horizontal, AppSpacingV3.md)
        .padding(.vertical, 10)
        .background(Color(hex: "F3F4F6")) // Bubble gray from HTML
        .cornerRadius(20)
        .lineLimit(1...5)
        .disabled(!viewModel.canSendMessages)
        .opacity(viewModel.canSendMessages ? 1.0 : 0.6)
    }

    private var sendButtonV3: some View {
        Button {
            Task { await viewModel.sendMessage() }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        viewModel.isComposerEnabled
                        ? AppColorsV3.forestGreen
                        : AppColorsV3.textSecondary.opacity(0.3)
                    )
                    .frame(width: 40, height: 40)

                if viewModel.isSending {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(!viewModel.isComposerEnabled)
    }

    // MARK: - Messages Area
    
    @ViewBuilder
    private var messagesArea: some View {
        if viewModel.isLoading && viewModel.messages.isEmpty {
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
        .background(AppColorsV3.surfaceWhite)
    }

    private var emptyStateView: some View {
        VStack(spacing: AppSpacingV3.md) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(AppColorsV3.forestGreen.opacity(0.4))

            Text("No messages yet")
                .font(AppTypographyV3.displayMediumSerif)
                .foregroundColor(AppColorsV3.textPrimary)

            if viewModel.canSendMessages {
                Text("Say hi to coordinate logistics!")
                    .font(AppTypographyV3.bodyRegular)
                    .foregroundColor(AppColorsV3.textSecondary)
            } else {
                Text("You'll get chat access once accepted.")
                    .font(AppTypographyV3.bodyRegular)
                    .foregroundColor(AppColorsV3.textSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColorsV3.surfaceWhite)
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacingV3.xs) {
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
                .padding(AppSpacingV3.contentPadding)
                .id(viewModel.senderProfiles.count) // Force re-render when profiles load
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColorsV3.surfaceWhite)
            .simultaneousGesture(
                TapGesture().onEnded {
                    // Dismiss keyboard when tapping messages area
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
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

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: AppSpacingV3.sm) {
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text("Uploading photo...")
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(.white)
            }
            .padding(AppSpacingV3.md)
            .background(AppColorsV3.surfaceWhite)
            .cornerRadius(AppSpacingV3.sm)
        }
    }
}

// MARK: - Identifiable String Wrapper

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

