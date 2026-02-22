import SwiftUI
import NukeUI

/// A circular avatar image backed by Nuke's shared pipeline.
///
/// Shows a person-icon placeholder when the URL is nil or loading fails.
///
/// Usage:
/// ```swift
/// TPAvatar(url: profilePhotoURL, size: 40)
/// ```
struct TPAvatar: View {

    let url: URL?
    var size: CGFloat = 40

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholderView: some View {
        Circle()
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.25)
                    .foregroundColor(Color(.systemGray3))
            )
    }
}
