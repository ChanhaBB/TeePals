import SwiftUI

/// Card view for displaying a post in the feed.
/// Shows author, text, photos, linked round, and interaction buttons.
struct PostCardView: View {

    let post: Post
    let linkedRound: Round?
    let onTap: () -> Void
    let onUpvote: () -> Void
    let onAuthorTap: () -> Void
    let onRoundTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Author info (has its own buttons)
            authorHeader

            // Content area (title + text + photos) - tappable to go to post detail
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Title
                if let title = post.title, !title.isEmpty {
                    Text(title)
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Text content (truncated)
                if !post.text.isEmpty {
                    Text(post.text)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Photos (in feed, these go to detail too - fullscreen only in detail view)
                if post.hasPhotos {
                    photoGridNonInteractive
                }
            }
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            // Linked round (has its own button)
            if post.linkedRoundId != nil {
                linkedRoundPreview
                    .padding(.bottom, AppSpacing.md)
            }

            // Footer: Time, interactions (has its own buttons for upvote)
            footer
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .cornerRadius(AppSpacing.radiusLarge)
    }
    
    // MARK: - Author Header
    
    private var authorHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            // Avatar
            Button(action: onAuthorTap) {
                avatarView
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Button(action: onAuthorTap) {
                    Text(post.authorNickname ?? "Unknown")
                        .font(AppTypography.labelLarge)
                        .foregroundColor(AppColors.textPrimary)
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 4) {
                    Text(post.timeAgoString)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textTertiary)
                    
                    if post.visibility == .friends {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    
                    if post.isEdited {
                        Text("• edited")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var avatarView: some View {
        Group {
            if let photoUrl = post.authorPhotoUrl, let url = URL(string: photoUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
    
    private var initialsView: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Text(String(post.authorNickname?.prefix(1) ?? "?"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.primary)
            )
    }
    
    // MARK: - Photo Grid (Non-Interactive for Feed)

    private var photoGridNonInteractive: some View {
        let photos = post.photoUrls.prefix(4)

        return Group {
            switch photos.count {
            case 1:
                singlePhotoNonInteractive(photos[0])
            case 2:
                twoPhotosNonInteractive(Array(photos))
            case 3:
                threePhotosNonInteractive(Array(photos))
            default:
                fourPhotosNonInteractive(Array(photos))
            }
        }
        .cornerRadius(AppSpacing.sm)
    }
    
    private func singlePhotoNonInteractive(_ url: String) -> some View {
        photoView(url: url)
            .frame(height: 200)
    }

    private func twoPhotosNonInteractive(_ urls: [String]) -> some View {
        HStack(spacing: 2) {
            photoView(url: urls[0])
            photoView(url: urls[1])
        }
        .frame(height: 160)
    }

    private func threePhotosNonInteractive(_ urls: [String]) -> some View {
        HStack(spacing: 2) {
            photoView(url: urls[0])
                .frame(width: UIScreen.main.bounds.width * 0.4)

            VStack(spacing: 2) {
                photoView(url: urls[1])
                photoView(url: urls[2])
            }
        }
        .frame(height: 160)
    }

    private func fourPhotosNonInteractive(_ urls: [String]) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                photoView(url: urls[0])
                photoView(url: urls[1])
            }
            HStack(spacing: 2) {
                photoView(url: urls[2])
                photoView(url: urls[3])
            }
        }
        .frame(height: 200)
    }

    private func photoView(url: String) -> some View {
        CachedAsyncImage(url: URL(string: url)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(AppColors.backgroundSecondary)
                .overlay(
                    ProgressView()
                )
        }
        .clipped()
    }
    
    // MARK: - Linked Round Preview

    private var linkedRoundPreview: some View {
        Button {
            if let roundId = post.linkedRoundId {
                onRoundTap(roundId)
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "flag.fill")
                    .font(.body)
                    .foregroundColor(AppColors.primary)

                if let round = linkedRound {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(round.displayCourseName)
                            .font(AppTypography.labelLarge)
                            .foregroundColor(AppColors.textPrimary)

                        if let dateTime = round.displayDateTime {
                            Text(dateTime)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                } else {
                    Text("Linked Round")
                        .font(AppTypography.labelLarge)
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.backgroundSecondary)
            .cornerRadius(AppSpacing.sm)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: AppSpacing.md) {
            // Like button
            Button(action: onUpvote) {
                HStack(spacing: 4) {
                    Image(systemName: post.hasUpvoted == true ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundColor(post.hasUpvoted == true ? AppColors.error : AppColors.textSecondary)

                    if post.upvoteCount > 0 {
                        Text("\(post.upvoteCount)")
                            .font(AppTypography.caption)
                            .foregroundColor(post.hasUpvoted == true ? AppColors.error : AppColors.textSecondary)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
                .padding(.horizontal, AppSpacing.xs)
            }
            .buttonStyle(.plain)

            // Comments - tappable to go to post detail
            Button(action: onTap) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)

                    if post.commentCount > 0 {
                        Text("\(post.commentCount)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
                .padding(.horizontal, AppSpacing.xs)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PostCardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                PostCardView(
                    post: Post(
                        id: "1",
                        authorUid: "user1",
                        text: "Had an amazing round today at Pebble Beach! The weather was perfect and I finally broke 80! ⛳️",
                        photoUrls: [],
                        visibility: .public,
                        upvoteCount: 12,
                        commentCount: 3,
                        authorNickname: "GolfPro123",
                        hasUpvoted: true
                    ),
                    linkedRound: nil,
                    onTap: {},
                    onUpvote: {},
                    onAuthorTap: {},
                    onRoundTap: { _ in }
                )

                PostCardView(
                    post: Post(
                        id: "2",
                        authorUid: "user2",
                        text: "Looking for playing partners this weekend!",
                        photoUrls: ["https://example.com/photo1.jpg", "https://example.com/photo2.jpg"],
                        linkedRoundId: "round1",
                        visibility: .friends,
                        isEdited: true,
                        authorNickname: "WeekendGolfer"
                    ),
                    linkedRound: nil,
                    onTap: {},
                    onUpvote: {},
                    onAuthorTap: {},
                    onRoundTap: { _ in }
                )
            }
            .padding()
        }
        .background(AppColors.backgroundGrouped)
    }
}
#endif

