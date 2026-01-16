import SwiftUI

/// Reusable profile identity section showing avatar, name, location, metadata, and bio.
/// Used in both self profile and public profile views.
struct ProfileIdentitySection: View {
    let profile: PublicProfile
    let onAvatarTap: (() -> Void)?

    @State private var isBioExpanded = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Avatar
            if let onAvatarTap = onAvatarTap {
                Button(action: onAvatarTap) {
                    avatarView
                }
                .buttonStyle(.plain)
            } else {
                avatarView
            }

            // Name
            Text(profile.nickname)
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)

            // Location
            if !profile.primaryCityLabel.isEmpty {
                Label(profile.primaryCityLabel, systemImage: "location.fill")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Metadata (Age · Gender · Skill)
            if hasMetadata {
                Text(metadataString)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Bio
            if let bio = profile.bio, !bio.isEmpty {
                bioView(bio)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .cornerRadius(AppRadii.card)
    }

    // MARK: - Avatar

    private var avatarView: some View {
        Group {
            if let firstPhotoUrl = profile.photoUrls.first, let url = URL(string: firstPhotoUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.primary.opacity(0.6))
            )
    }

    // MARK: - Metadata String

    private var hasMetadata: Bool {
        profile.age != nil || profile.gender != nil || profile.skillLevel != nil
    }

    private var metadataString: String {
        var parts: [String] = []

        if let age = profile.age {
            parts.append("\(age)")
        }

        if let gender = profile.gender {
            parts.append(gender.displayText)
        }

        if let skill = profile.skillLevel {
            parts.append(skill.displayText)
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Bio View

    private func bioView(_ bio: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(bio)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(isBioExpanded ? nil : 2)

            // Show More/Less button if bio is long
            if bioNeedsExpansion(bio) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBioExpanded.toggle()
                    }
                } label: {
                    Text(isBioExpanded ? "Less" : "More")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }

    private func bioNeedsExpansion(_ text: String) -> Bool {
        // Rough heuristic: if text is longer than ~100 chars, it likely wraps beyond 2 lines
        return text.count > 100
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: AppSpacing.lg) {
        ProfileIdentitySection(
            profile: PublicProfile(
                id: "preview",
                nickname: "Alex",
                photoUrls: [],
                gender: .male,
                occupation: "Software Engineer",
                bio: "Weekend golfer trying to break 90. Love morning tee times and playing with new people!",
                primaryCityLabel: "San Jose, CA",
                primaryLocation: GeoLocation(latitude: 37.3382, longitude: -121.8863),
                avgScore: 94,
                experienceLevel: .fourToSix,
                playsPerMonth: 3,
                skillLevel: .intermediate,
                birthYear: 1998
            ),
            onAvatarTap: { print("Avatar tapped") }
        )

        Spacer()
    }
    .padding()
    .background(AppColors.backgroundGrouped)
}
#endif
