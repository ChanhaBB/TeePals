import SwiftUI

/// Simple form field row with leading icon.
/// Used for consistent form field styling.
struct FormFieldRow<Content: View>: View {
    let icon: String
    @ViewBuilder let content: Content
    
    init(icon: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            content
        }
    }
}

#if DEBUG
#Preview {
    Form {
        FormFieldRow(icon: "person.fill") {
            TextField("Name", text: .constant("John"))
        }
        FormFieldRow(icon: "envelope.fill") {
            TextField("Email", text: .constant("john@example.com"))
        }
    }
}
#endif

