import SwiftUI
import NukeUI
import Nuke

/// A reusable image view backed by Nuke's shared pipeline.
///
/// `TPImage` wraps `LazyImage` with sensible defaults:
/// - Images fill the container and are clipped (no layout blow-out)
/// - A neutral placeholder is shown during loading and on failure
/// - All images share the same memory + disk cache via `ImagePipeline.shared`
///
/// Usage:
/// ```swift
/// TPImage(url: someURL)
///     .frame(width: 120, height: 80)
///     .clipShape(RoundedRectangle(cornerRadius: 8))
/// ```
struct TPImage: View {

    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(Color(.systemGray3))
            )
    }
}

// MARK: - Convenience modifiers

extension TPImage {
    /// Override the default `.fill` content mode.
    func contentMode(_ mode: ContentMode) -> TPImage {
        var copy = self
        copy.contentMode = mode
        return copy
    }
}
