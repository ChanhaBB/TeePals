import SwiftUI

/// A lightweight section container with optional title and subtitle.
/// Provides visual grouping with subtle background and consistent padding.
struct SectionCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = title {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

/// Helper text displayed below inputs - clearly secondary but readable.
struct AssistiveText: View {
    let text: String
    let icon: String?
    
    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.subheadline)
            }
            Text(text)
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(spacing: 16) {
        SectionCard(title: "Visibility", subtitle: "Who can see this round?") {
            Text("Content goes here")
        }
        
        SectionCard {
            Text("No title card")
        }
        
        AssistiveText("Players will request to join", icon: "hand.raised.fill")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

