import SwiftUI

/// Chat message composer with text input and send button.
struct ChatComposer: View {
    
    @Binding var text: String
    let isEnabled: Bool
    let isSending: Bool
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
            // Keyboard dismiss button (only when focused)
            if isFocused {
                Button {
                    isFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            textField
            sendButton
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
    
    // MARK: - Text Field
    
    private var textField: some View {
        TextField(
            isEnabled ? "Type a message..." : "Chat access required",
            text: $text,
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(AppTypography.bodyMedium)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.backgroundSecondary)
        .cornerRadius(AppSpacing.radiusMedium)
        .lineLimit(1...5)
        .focused($isFocused)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .onSubmit {
            if canSend {
                onSend()
            }
        }
    }
    
    // MARK: - Send Button
    
    private var sendButton: some View {
        Button {
            onSend()
            // Keep keyboard open for continued typing
        } label: {
            ZStack {
                if isSending {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
            }
            .foregroundColor(canSend ? AppColors.primary : AppColors.textTertiary)
        }
        .disabled(!canSend)
        .animation(.easeInOut(duration: 0.15), value: canSend)
    }
    
    // MARK: - Helpers
    
    private var canSend: Bool {
        isEnabled && !isSending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview

#if DEBUG
struct ChatComposer_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            // Enabled state
            ChatComposer(
                text: .constant("Hello!"),
                isEnabled: true,
                isSending: false,
                onSend: {}
            )
            
            Divider()
            
            // Disabled state
            ChatComposer(
                text: .constant(""),
                isEnabled: false,
                isSending: false,
                onSend: {}
            )
            
            Divider()
            
            // Sending state
            ChatComposer(
                text: .constant("Sending..."),
                isEnabled: true,
                isSending: true,
                onSend: {}
            )
        }
        .background(AppColors.backgroundGrouped)
    }
}
#endif

