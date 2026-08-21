import SwiftUI

struct ProfileAvatarView: View {
    let url: String?
    let size: CGFloat
    var onTap: (() -> Void)?

    var body: some View {
        let avatarContent = TPAvatar(
            url: url.flatMap { URL(string: $0) },
            size: size
        )

        return Group {
            if let onTap = onTap, url != nil {
                Button(action: onTap) {
                    avatarContent
                }
                .buttonStyle(.plain)
            } else {
                avatarContent
            }
        }
    }
}
