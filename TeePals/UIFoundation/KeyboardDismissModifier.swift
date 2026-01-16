import SwiftUI

/// A view modifier that adds a "Done" button to the keyboard toolbar.
/// Use this on any view containing text fields to provide consistent keyboard dismissal.
///
/// Usage:
/// ```
/// NavigationStack {
///     // content with text fields
/// }
/// .keyboardDismissToolbar()
/// ```
struct KeyboardDismissToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

extension View {
    /// Adds a "Done" button to the keyboard toolbar for dismissing the keyboard.
    func keyboardDismissToolbar() -> some View {
        modifier(KeyboardDismissToolbar())
    }
}

