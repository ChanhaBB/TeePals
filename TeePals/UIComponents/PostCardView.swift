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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Header: Author info
                authorHeader
                
                // Text content
                if !post.text.isEmpty {
                    Text(post.text)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                }
                
                // Photos
                if post.hasPhotos {
                    photoGrid
                }
                
                // Linked round
                if post.linkedRoundId != nil {
                    linkedRoundPreview
                }
                
                // Footer: Time, interactions
                footer
            }
            .padding(AppSpacing.lg)
            .background(AppColors.surface)
            .cornerRadius(AppSpacing.radiusLarge)
        }
        .buttonStyle(.plain)
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
    
    // MARK: - Photo Grid
    
    private var photoGrid: some View {
        let photos = post.photoUrls.prefix(4)
        
        return Group {
            switch photos.count {
            case 1:
                singlePhoto(photos[0])
            case 2:
                twoPhotos(Array(photos))
            case 3:
                threePhotos(Array(photos))
            default:
                fourPhotos(Array(photos))
            }
        }
        .cornerRadius(AppSpacing.sm)
    }
    
    private func singlePhoto(_ url: String) -> some View {
        photoView(url: url)
            .frame(height: 200)
    }
    
    private func twoPhotos(_ urls: [String]) -> some View {
        HStack(spacing: 2) {
            photoView(url: urls[0])
            photoView(url: urls[1])
        }
        .frame(height: 160)
    }
    
    private func threePhotos(_ urls: [String]) -> some View {
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
    
    private func fourPhotos(_ urls: [String]) -> some View {
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
        HStack(spacing: AppSpacing.lg) {
            // Upvote button
            Button(action: onUpvote) {
                HStack(spacing: 4) {
                    Image(systemName: post.hasUpvoted == true ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.body)
                        .foregroundColor(post.hasUpvoted == true ? AppColors.primary : AppColors.textSecondary)
                    
                    if post.upvoteCount > 0 {
                        Text("\(post.upvoteCount)")
                            .font(AppTypography.caption)
                            .foregroundColor(post.hasUpvoted == true ? AppColors.primary : AppColors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Comments
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

