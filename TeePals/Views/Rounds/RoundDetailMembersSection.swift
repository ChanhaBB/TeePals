import SwiftUI

// MARK: - Players Section (Host + Members Combined)

struct RoundDetailPlayersSection: View {
    let hostUid: String
    let hostProfile: PublicProfile?
    let members: [RoundMember]
    let profiles: [String: PublicProfile]
    let spotsRemaining: Int
    let maxPlayers: Int
    let currentUserUid: String?
    let isCurrentUserHost: Bool
    let canInvite: Bool
    let onProfileTap: (String) -> Void
    let onRemoveMember: ((String) -> Void)?
    let onInvite: (() -> Void)?
    
    // Filter out host from members list (host is shown separately at top)
    private var nonHostMembers: [RoundMember] {
        members.filter { $0.uid != hostUid }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header
            
            AppCard(style: .elevated) {
                VStack(spacing: AppSpacing.sm) {
                    // Host row (always first)
                    PlayerRowView(
                        uid: hostUid,
                        profile: hostProfile,
                        isHost: true,
                        isCurrentUser: hostUid == currentUserUid,
                        canBeRemoved: false,
                        onTap: { onProfileTap(hostUid) },
                        onRemove: nil
                    )
                    
                    // Other members
                    ForEach(nonHostMembers, id: \.uid) { member in
                        Divider()
                        PlayerRowView(
                            uid: member.uid,
                            profile: profiles[member.uid],
                            isHost: false,
                            isCurrentUser: member.uid == currentUserUid,
                            canBeRemoved: isCurrentUserHost && member.uid != currentUserUid,
                            onTap: { onProfileTap(member.uid) },
                            onRemove: isCurrentUserHost ? { onRemoveMember?(member.uid) } : nil
                        )
                    }
                    
                    // Empty spots
                    if spotsRemaining > 0 {
                        Divider()
                        emptySpotRow
                    }
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("PLAYERS")
                .font(AppTypography.labelMedium)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text("\(members.count)/\(maxPlayers)")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var emptySpotRow: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .stroke(AppColors.border, style: StrokeStyle(lineWidth: 2, dash: [4]))
                    .frame(width: 44, height: 44)
                Image(systemName: "plus")
                    .foregroundColor(AppColors.textSecondary)
            }
            Text("\(spotsRemaining) spot\(spotsRemaining == 1 ? "" : "s") available")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            Spacer()

            // Invite button (visible if user can invite)
            if canInvite, let onInvite = onInvite {
                Button {
                    onInvite()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.caption)
                        Text("Invite")
                            .font(AppTypography.labelMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.primary)
                    .cornerRadius(AppSpacing.radiusSmall)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Player Row

struct PlayerRowView: View {
    let uid: String
    let profile: PublicProfile?
    let isHost: Bool
    let isCurrentUser: Bool
    let canBeRemoved: Bool
    let onTap: () -> Void
    let onRemove: (() -> Void)?
    
    @State private var showingRemoveConfirmation = false
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ProfileAvatarView(url: profile?.photoUrls.first, size: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile?.nickname ?? "Player")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if isHost {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.primary)
                    }
                }
                
                if let skill = profile?.skillLevel {
                    Text(skill.displayText)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            if canBeRemoved {
                Button {
                    showingRemoveConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.error.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .confirmationDialog(
            "Remove \(profile?.nickname ?? "this player")?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove from Round", role: .destructive) {
                onRemove?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will be notified and removed from the round chat.")
        }
    }
}

// MARK: - Profile Avatar View

struct ProfileAvatarView: View {
    let url: String?
    let size: CGFloat
    var onTap: (() -> Void)?

    var body: some View {
        let avatarContent = Group {
            if let urlString = url, let imageUrl = URL(string: urlString) {
                CachedAsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())

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
    
    private var placeholderView: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(AppColors.primary.opacity(0.6))
            )
    }
}
