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
            TPAvatar(url: URL(string: userProfilePhotoUrl ?? ""), size: 40)

            // Oval text field capsule (grows with content)
            HStack(alignment: .bottom, spacing: 8) {
                FocusableTextView(
                    text: $viewModel.newCommentText,
                    placeholder: "Join the conversation...",
                    font: UIFont.systemFont(ofSize: 15),
                    shouldFocus: isCommentFocused,
                    onFocusChange: { focused in
                        // ALWAYS defer SwiftUI state mutations via Task
                        // This prevents "Publishing changes from within view updates" warning
                        // The userDismissedKeyboard flag (non-SwiftUI) prevents refocus races
                        Task { @MainActor in
                            if focused {
                                // Only update inputState (source of truth)
                                // isCommentFocused derives from it via computed binding
                                inputState = .active
                            } else {
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
