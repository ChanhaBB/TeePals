import SwiftUI

// MARK: - Comment Input State

enum CommentInputState {
    case resting  // Not focused, no draft
    case draft    // Not focused, has draft
    case active   // Focused, editing
}

// MARK: - Comment Input Bar

/// Comment input bar with profile photo, text editor, and action buttons.
/// Handles keyboard focus, draft state, and submission.
struct CommentInputBar: View {
    @ObservedObject var viewModel: PostDetailViewModel
    @Binding var isCommentFocused: Bool
    @Binding var inputState: CommentInputState
    @State private var dynamicHeight: CGFloat = 36  // Track dynamic height
    let userProfilePhotoUrl: String?
    let onActivate: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Profile photo (bigger for prominence)
            CachedAsyncImage(url: URL(string: userProfilePhotoUrl ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(AppColors.textTertiary.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(AppColors.textTertiary.opacity(0.6))
                            .font(.system(size: 20))
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            // Oval text field capsule (grows with content)
            HStack(alignment: .bottom, spacing: 8) {
                FocusableTextView(
                    text: $viewModel.newCommentText,
                    placeholder: viewModel.replyingTo != nil
                        ? "Replying to @\(viewModel.replyingTo?.authorNickname ?? "user")"
                        : "Join the conversation...",
                    font: UIFont.systemFont(ofSize: 15),
                    shouldFocus: isCommentFocused,
                    onFocusChange: { focused in
                        // ALWAYS defer SwiftUI state mutations via Task
                        // This prevents "Publishing changes from within view updates" warning
                        // The userDismissedKeyboard flag (non-SwiftUI) prevents refocus races
                        Task { @MainActor in
                            if focused {
                                isCommentFocused = true
                                inputState = .active
                            } else {
                                isCommentFocused = false
                                viewModel.commentDraft = viewModel.newCommentText
                                inputState = viewModel.hasDraft ? .draft : .resting
                            }
                        }
                    },
                    onHeightChange: { newHeight in
                        // Only update when height changes by more than 0.5pt (prevents jitter)
                        // NO ANIMATION - prevents AttributeGraph cycles during focus transitions
                        if abs(newHeight - self.dynamicHeight) > 0.5 {
                            self.dynamicHeight = newHeight
                        }
                    }
                )
                .frame(height: dynamicHeight)  // Now dynamic!

                // Right button (Clear or Post)
                if inputState == .draft && !isCommentFocused {
                    // Clear button when draft exists and not focused
                    Button {
                        viewModel.commentDraft = ""
                        viewModel.newCommentText = ""
                        inputState = .resting
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                            .font(.system(size: 22))
                    }
                    .padding(.bottom, 4)
                } else if isCommentFocused || viewModel.canSubmitComment {
                    // Post button (up arrow icon like IG)
                    Button {
                        Task {
                            // Dismiss keyboard first
                            isCommentFocused = false
                            // Then submit
                            await viewModel.submitComment()
                            // Clear reply target so placeholder resets
                            viewModel.setReplyTarget(nil)
                            inputState = .resting
                        }
                    } label: {
                        if viewModel.isSubmittingComment {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(viewModel.canSubmitComment ? AppColors.primary : AppColors.textTertiary)
                        }
                    }
                    .disabled(!viewModel.canSubmitComment)
                    .padding(.bottom, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, 8)
        .background(AppColors.surface.ignoresSafeArea(edges: .bottom))
        .onTapGesture {
            if !isCommentFocused {
                onActivate()
            }
        }
    }
}
