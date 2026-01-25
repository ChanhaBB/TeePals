import SwiftUI

/// View for displaying another user's public profile with Instagram-inspired layout.
struct OtherUserProfileView: View {
    @StateObject private var viewModel: OtherUserProfileViewModel
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var showingPhotoViewer = false

    init(viewModel: OtherUserProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()
                content
            }
            .navigationTitle(viewModel.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingFollowers) {
                FollowersListView(uid: viewModel.uid, mode: .followers)
                    .environmentObject(container)
            }
            .sheet(isPresented: $showingFollowing) {
                FollowersListView(uid: viewModel.uid, mode: .following)
                    .environmentObject(container)
            }
            .fullScreenCover(isPresented: $showingPhotoViewer) {
                if let profile = viewModel.profile {
                    PhotoViewerView(photoUrls: profile.photoUrls, initialIndex: 0)
                }
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.profile == nil {
            ProgressView()
        } else if let error = viewModel.errorMessage, viewModel.profile == nil {
            errorView(error)
        } else if let profile = viewModel.profile {
            profileContent(profile)
        } else {
            Text("Profile not found")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Profile Content

    private func profileContent(_ profile: PublicProfile) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                unifiedHeader(profile: profile)

                // Follow button
                if !viewModel.isOwnProfile {
                    followButton
                }

                aboutMeCard(profile: profile)
                golfCard(profile: profile)
                postsCard
            }
            .padding(AppSpacing.contentPadding)
        }
    }

    // MARK: - Unified Header (Instagram-style)

    private func unifiedHeader(profile: PublicProfile) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Photo (tappable to view)
            Button {
                if !profile.photoUrls.isEmpty {
                    showingPhotoViewer = true
                }
            } label: {
                photoDisplay(profile: profile)
            }
            .buttonStyle(.plain)
            .disabled(profile.photoUrls.isEmpty)

            // Name
            Text(profile.nickname)
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)

            // Stats inline
            HStack(spacing: 0) {
                Button {
                    showingFollowing = true
                } label: {
                    statItem(count: viewModel.followingCount, label: "Following")
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 40)
                    .padding(.horizontal, AppSpacing.lg)

                Button {
                    showingFollowers = true
                } label: {
                    statItem(count: viewModel.followerCount, label: "Followers")
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, AppSpacing.sm)

            // Bio (read-only)
            bioSection(profile: profile)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .cornerRadius(AppRadii.card)
    }

    private func photoDisplay(profile: PublicProfile) -> some View {
        Group {
            if let photoUrl = profile.photoUrls.first, let url = URL(string: photoUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    photoPlaceholder
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var photoPlaceholder: some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.primary.opacity(0.6))
            )
    }

    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text("\(count)")
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func bioSection(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppRadii.card)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.sm)
    }

    private func buildPersonalInfo(profile: PublicProfile) -> String? {
        var parts: [String] = []
        if let age = profile.age {
            parts.append("\(age)")
        }
        if let gender = profile.gender {
            parts.append(gender.displayText)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - About Me Card

    private func aboutMeCard(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("About Me")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                // Location
                if !profile.primaryCityLabel.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.primary)
                        Text(profile.primaryCityLabel)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Age & Gender
                if let personalInfo = buildPersonalInfo(profile: profile), !personalInfo.isEmpty {
                    Text(personalInfo)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Instagram
                if let instagram = profile.instagramUsername, !instagram.isEmpty {
                    instagramButton(username: instagram)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadii.card)
    }

    private func instagramButton(username: String) -> some View {
        Button {
            let urlString = username.hasPrefix("@") ? "https://instagram.com/\(String(username.dropFirst()))" : "https://instagram.com/\(username)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Text("IG")
                    .font(AppTypography.labelSmall)
                    .foregroundColor(AppColors.primary)
                    .fontWeight(.semibold)
                Text("@\(username.hasPrefix("@") ? String(username.dropFirst()) : username)")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Golf Card

    private func golfCard(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Golf")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                // Skill Level (always show)
                HStack(spacing: 8) {
                    Text("Skill Level:")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(profile.skillLevel?.displayText ?? "Not set")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(profile.skillLevel == nil ? AppColors.textTertiary : AppColors.textPrimary)
                }

                // Plays per Month (hide if empty)
                if let plays = profile.playsPerMonth {
                    HStack(spacing: 8) {
                        Text("Plays:")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(plays) times/month")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }

                // Avg Score (hide if empty)
                if let score = profile.avgScore {
                    HStack(spacing: 8) {
                        Text("Avg Score:")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(score)+")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadii.card)
    }

    // MARK: - Follow Button

    private var followButton: some View {
        Group {
            if viewModel.isMutualFollow {
                // Mutual follow = Friends
                SecondaryButton(
                    "Friends",
                    icon: "person.2.fill"
                ) {
                    Task { await viewModel.toggleFollow() }
                }
            } else if viewModel.isFollowing {
                // One-way follow (you follow them)
                SecondaryButton(
                    "Following",
                    icon: "checkmark"
                ) {
                    Task { await viewModel.toggleFollow() }
                }
            } else if viewModel.isFollowedByThem {
                // They follow you - show "Follow Back"
                PrimaryButton(
                    "Follow Back",
                    icon: "arrow.turn.down.left"
                ) {
                    Task { await viewModel.toggleFollow() }
                }
            } else {
                // No relationship
                PrimaryButton(
                    "Follow",
                    icon: "plus"
                ) {
                    Task { await viewModel.toggleFollow() }
                }
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Posts Card

    private var postsCard: some View {
        NavigationLink {
            PostsListScreen(uid: viewModel.uid)
                .environmentObject(container)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Posts")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("View all posts")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(AppRadii.card)
        }
        .buttonStyle(.plain)
    }
}
