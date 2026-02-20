import SwiftUI
import UIKit

// MARK: - Focusable TextView Wrapper

/// SwiftUI wrapper for text input with external focus control
struct FocusableTextView: View {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let shouldFocus: Bool
    let onFocusChange: ((Bool) -> Void)?
    let onHeightChange: ((CGFloat) -> Void)?

    init(
        text: Binding<String>,
        placeholder: String,
        font: UIFont,
        shouldFocus: Bool,
        onFocusChange: ((Bool) -> Void)? = nil,
        onHeightChange: ((CGFloat) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.shouldFocus = shouldFocus
        self.onFocusChange = onFocusChange
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        UIKitTextView(
            text: $text,
            placeholder: placeholder,
            font: font,
            shouldFocus: shouldFocus,
            onFocusChange: onFocusChange,
            onHeightChange: onHeightChange ?? { _ in }
        )
    }
}

// MARK: - UIKit TextView Wrapper

/// UIKit TextView wrapper with focus change callback.
struct UIKitTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let shouldFocus: Bool
    let onFocusChange: ((Bool) -> Void)?
    let onHeightChange: (CGFloat) -> Void

    init(text: Binding<String>, placeholder: String, font: UIFont, shouldFocus: Bool = false, onFocusChange: ((Bool) -> Void)? = nil, onHeightChange: @escaping (CGFloat) -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.shouldFocus = shouldFocus
        self.onFocusChange = onFocusChange
        self.onHeightChange = onHeightChange
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = font
        textView.delegate = context.coordinator
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.isScrollEnabled = false  // Start disabled, enable dynamically when content exceeds 150pt
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        // Ensure it can become first responder immediately
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Initialize placeholder label on first creation
        context.coordinator.updatePlaceholder(in: textView)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update text if changed
        if uiView.text != text {
            uiView.text = text
            // CRITICAL: Update placeholder visibility when text changes programmatically
            // Without this, clearing text from SwiftUI (e.g., after posting) leaves placeholder hidden
            context.coordinator.updatePlaceholder(in: uiView)
        }

        // FOCUS LOGIC: Sync UIKit state with SwiftUI intent
        let isActuallyFocused = uiView.isFirstResponder

        if shouldFocus && !isActuallyFocused {
            // SwiftUI wants focus, but UIKit doesn't have it

            // CRITICAL GUARD: If user just dismissed keyboard, SwiftUI state may be stale
            // Don't refocus until the deferred Task updates shouldFocus to false
            if context.coordinator.userDismissedKeyboard {
                // User explicitly dismissed - ignore stale focus request
                return
            }

            // CRITICAL: Always defer becomeFirstResponder to AFTER current SwiftUI update
            // Calling it synchronously causes AttributeGraph cycle (SwiftUI tries to update
            // focus state while already in the middle of an update pass)
            DispatchQueue.main.async {
                if uiView.window != nil && !uiView.isFirstResponder {
                    uiView.becomeFirstResponder()
                }
            }
        } else if !shouldFocus {
            // SwiftUI wants unfocus
            if isActuallyFocused {
                // CRITICAL: Defer resignFirstResponder to avoid AttributeGraph cycle
                // Same issue as becomeFirstResponder - calling it synchronously during
                // SwiftUI's update pass causes cycle detection
                DispatchQueue.main.async {
                    uiView.resignFirstResponder()
                }
            }
            // Clear dismissal flag now that we're settled in unfocused state
            // This allows future focus requests (Reply button) to work
            context.coordinator.userDismissedKeyboard = false
        }

        // Height updates ONLY triggered by textViewDidChange (prevents layout loops)

        // Placeholder Update: Only if changed (prevents redundant updates)
        if context.coordinator.placeholder != placeholder {
            context.coordinator.placeholder = placeholder
            context.coordinator.updatePlaceholder(in: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        // Cleanup handled automatically
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder, onFocusChange: onFocusChange, onHeightChange: onHeightChange)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var placeholder: String  // Changed from 'let' to 'var' so it can update
        let onFocusChange: ((Bool) -> Void)?
        let onHeightChange: (CGFloat) -> Void
        private var placeholderLabel: UILabel?
        private var lastReportedHeight: CGFloat = 36  // Track last height to prevent loops
        private var hasReportedFocus = false  // Track if we've already reported this focus state

        // CRITICAL: Flag to prevent refocus race without mutating SwiftUI state
        // This is set immediately when user dismisses keyboard, preventing refocus
        // even while SwiftUI state is still stale (deferred via Task)
        var userDismissedKeyboard = false

        init(text: Binding<String>, placeholder: String, onFocusChange: ((Bool) -> Void)?, onHeightChange: @escaping (CGFloat) -> Void) {
            _text = text
            self.placeholder = placeholder
            self.onFocusChange = onFocusChange
            self.onHeightChange = onHeightChange
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Clear dismissal flag (user is now actively typing)
            userDismissedKeyboard = false

            // Only notify SwiftUI if we haven't already reported focused state
            // This prevents redundant callbacks when activateComposer triggers focus
            if !hasReportedFocus {
                hasReportedFocus = true
                onFocusChange?(true)
            }
            updatePlaceholder(in: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // Set flag IMMEDIATELY (non-SwiftUI state, no warning)
            // This prevents refocus even while SwiftUI state is stale
            userDismissedKeyboard = true

            // Only notify SwiftUI if we're transitioning from focused to unfocused
            if hasReportedFocus {
                hasReportedFocus = false
                // DEFER SwiftUI state update to prevent "Publishing changes" warning
                onFocusChange?(false)
            }
            // Restore placeholder visibility if text is empty
            updatePlaceholder(in: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            updateHeightIfNeeded(textView)
            updatePlaceholder(in: textView)
        }

        func updateHeightIfNeeded(_ textView: UITextView) {
            let size = textView.sizeThatFits(CGSize(width: textView.frame.width, height: .infinity))
            // Clamp between 36pt (1 line) and 120pt (~5 lines)
            let newHeight = min(max(36, size.height), 120)

            // Only report if height changed significantly (1pt threshold to avoid jitter)
            if abs(newHeight - lastReportedHeight) > 1.0 {
                lastReportedHeight = newHeight
                onHeightChange(newHeight)
            }

            // Enable scrolling ONLY when we hit max height (immediate, not async)
            textView.isScrollEnabled = size.height > 120
        }

        func updatePlaceholder(in textView: UITextView) {
            // Create placeholder label if needed
            if placeholderLabel == nil {
                let label = UILabel()
                label.font = textView.font
                label.textColor = UIColor.placeholderText
                label.numberOfLines = 0
                label.translatesAutoresizingMaskIntoConstraints = false
                textView.addSubview(label)

                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 8),
                    label.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -8),
                    label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8)
                ])

                placeholderLabel = label
            }

            // Always update placeholder text (not just on creation)
            placeholderLabel?.text = placeholder
            // Show/hide placeholder based on text content
            placeholderLabel?.isHidden = !textView.text.isEmpty
        }
    }
}
