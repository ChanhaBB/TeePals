import SwiftUI
import PhotosUI

/// Profile tab view - displays user's profile with Instagram-inspired layout.
/// Supports loading, empty, error states per UI_RULES.md.
struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var container: AppContainer

    @State private var showingSignOutAlert = false
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var showingBioEdit = false
    @State private var showingAboutMeEdit = false
    @State private var showingGolfEdit = false
    @State private var showingPhotoViewer = false
    @State private var showingPhotoActions = false
    @State private var showingPhotoPicker = false
    @State private var selectedBadge: String?

    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoEditViewModel: ProfileEditViewModel?

    // ViewModels for edit sheets
    @State private var bioEditViewModel: ProfileEditViewModel?
    @State private var aboutMeEditViewModel: ProfileEditViewModel?
    @State private var golfEditViewModel: ProfileEditViewModel?

    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()
                content
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadProfile() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
                Task { await viewModel.forceRefresh() }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) { authService.signOut() }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showingFollowers) {
                if let uid = viewModel.uid {
                    FollowersListView(uid: uid, mode: .followers)
                        .environmentObject(container)
                }
            }
            .sheet(isPresented: $showingFollowing) {
                if let uid = viewModel.uid {
                    FollowersListView(uid: uid, mode: .following)
                        .environmentObject(container)
                }
            }
            .sheet(isPresented: $showingBioEdit) {
                if let bioVM = bioEditViewModel {
                    BioEditSheet(viewModel: bioVM) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .sheet(isPresented: $showingAboutMeEdit) {
                if let aboutVM = aboutMeEditViewModel {
                    AboutMeEditSheet(viewModel: aboutVM) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .sheet(isPresented: $showingGolfEdit) {
                if let golfVM = golfEditViewModel {
                    GolfEditSheet(viewModel: golfVM) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .onChange(of: showingBioEdit) { _, newValue in
                if !newValue { bioEditViewModel = nil }
            }
            .onChange(of: showingAboutMeEdit) { _, newValue in
                if !newValue { aboutMeEditViewModel = nil }
            }
            .onChange(of: showingGolfEdit) { _, newValue in
                if !newValue { golfEditViewModel = nil }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await uploadPhoto(image)
                    }
                }
            }
            .confirmationDialog("Profile Photo", isPresented: $showingPhotoActions) {
                Button("Change Photo") {
                    showingPhotoPicker = true
                }
                Button("Remove Photo", role: .destructive) {
                    Task { await deletePhoto() }
                }
                Button("Cancel", role: .cancel) { }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .fullScreenCover(isPresented: $showingPhotoViewer) {
                if let profile = viewModel.publicProfile, !profile.photoUrls.isEmpty {
                    PhotoViewerView(photoUrls: profile.photoUrls, initialIndex: 0)
                }
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeExplanationView(badgeName: badge)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingState
        } else if let error = viewModel.errorMessage {
            errorState(error)
        } else if let profile = viewModel.publicProfile {
            profileContent(profile: profile)
        } else {
            emptyState
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                SkeletonCard(style: .profileCard)
                AppCard(style: .elevated) {
                    HStack(spacing: AppSpacing.xl) { statSkeleton; statSkeleton }
                }
            }
            .padding(AppSpacing.contentPadding)
        }
    }

    private var statSkeleton: some View {
        VStack(spacing: AppSpacing.xs) {
            SkeletonShape(width: 40, height: 24)
            SkeletonShape(width: 70, height: 14)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        ScrollView {
            EmptyStateView.noProfile { /* No action needed */ }
                .padding(.top, AppSpacing.xl)
        }
    }

    private func errorState(_ message: String) -> some View {
        ScrollView {
            VStack {
                Spacer(minLength: AppSpacing.xxl)
                InlineErrorBanner(message, actionTitle: "Retry") {
                    viewModel.errorMessage = nil
                    Task { await viewModel.loadProfile() }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                Spacer()
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(profile: PublicProfile) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                unifiedHeader(profile: profile)

                aboutMeCard(profile: profile)
                golfCard(profile: profile)
                badgesCard(profile: profile)
                myPostsButton
                signOutSection

                // TESTING ONLY - Commented out for beta
                // #if DEBUG
                // TestDataSection()
                // #endif
            }
            .padding(AppSpacing.contentPadding)
        }
    }

    // MARK: - Unified Header (Instagram-style)

    private func unifiedHeader(profile: PublicProfile) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Photo with camera icon
            ZStack(alignment: .bottomTrailing) {
                // Tap to view fullscreen
                if !profile.photoUrls.isEmpty {
                    Button {
                        showingPhotoViewer = true
                    } label: {
                        photoDisplay(profile: profile)
                    }
                    .buttonStyle(.plain)
                } else {
                    photoDisplay(profile: profile)
                }

                // Camera icon overlay - change/delete if photo exists, add if not
                if !profile.photoUrls.isEmpty {
                    Button {
                        showingPhotoActions = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                    }
                    .offset(x: -2, y: -2)
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1)
                    }
                    .offset(x: -2, y: -2)
                }
            }

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

            // Bio (tappable to edit)
            bioSection(profile: profile)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.surface)
        .cornerRadius(AppRadii.card)
    }

    private func photoDisplay(profile: PublicProfile) -> some View {
        TPAvatar(
            url: profile.photoUrls.first.flatMap { URL(string: $0) },
            size: 100
        )
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
                // Show full bio with grey background
                Button {
                    bioEditViewModel = container.makeProfileEditViewModel()
                    showingBioEdit = true
                } label: {
                    HStack {
                        Text(bio)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundSecondary)
                    .cornerRadius(AppRadii.card)
                }
                .buttonStyle(.plain)
            } else {
                // Empty state (tap to add)
                Button {
                    bioEditViewModel = container.makeProfileEditViewModel()
                    showingBioEdit = true
                } label: {
                    HStack {
                        Text("Add bio...")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textTertiary)
                            .italic()

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.sm)
    }

    private func buildPersonalInfo(profile: PublicProfile) -> String? {
        var parts: [String] = []
        // Use accurate age from ViewModel (PrivateProfile) instead of approximation
        if let age = viewModel.age {
            parts.append("\(age)")
        }
        if let gender = profile.gender {
            parts.append(gender.displayText)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - About Me Card

    private func aboutMeCard(profile: PublicProfile) -> some View {
        Button {
            aboutMeEditViewModel = container.makeProfileEditViewModel()
            showingAboutMeEdit = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("About Me")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                }

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
        .buttonStyle(.plain)
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
        Button {
            golfEditViewModel = container.makeProfileEditViewModel()
            showingGolfEdit = true
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("Golf")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(AppColors.textTertiary)
                }

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
        .buttonStyle(.plain)
    }

    // MARK: - Badges Card

    private func badgesCard(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Header
            Text("Achievements")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            if profile.earnedBadges.isEmpty {
                // Empty state
                Text("Play more rounds to unlock badges!")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 4)
            } else {
                // Badges grid
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(profile.earnedBadges, id: \.self) { badge in
                        Button {
                            selectedBadge = badge
                        } label: {
                            HStack(spacing: 10) {
                                Text(badge)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Play again stat (if eligible)
                    if profile.shouldShowPlayAgainStat {
                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 8) {
                            Text("Would Play Again:")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(Int(profile.recentWouldPlayAgainPct * 100))%")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.success)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(AppRadii.card)
    }

    // MARK: - My Posts Button

    private var myPostsButton: some View {
        NavigationLink {
            if let uid = viewModel.uid {
                PostsListScreen(uid: uid)
                    .environmentObject(container)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Posts")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Posts you've shared")
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

    // MARK: - Sign Out

    private var signOutSection: some View {
        Button { showingSignOutAlert = true } label: {
            HStack(spacing: AppSpacing.iconSpacing) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14))
                Text("Sign Out")
            }
            .font(AppTypography.bodyMedium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .foregroundColor(AppColors.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Actions

    private func uploadPhoto(_ image: UIImage) async {
        let vm = photoEditViewModel ?? container.makeProfileEditViewModel()
        photoEditViewModel = vm

        // Load profile if needed
        await vm.loadProfile()

        // Delete all existing photos (we only support single photo)
        while !vm.photoUrls.isEmpty {
            await vm.deletePhoto(at: 0)
        }

        // Upload new photo
        await vm.uploadPhoto(image)

        // Save profile
        _ = await vm.saveProfile()

        // Refresh view
        await viewModel.refresh()

        // Reset
        selectedPhotoItem = nil
        photoEditViewModel = nil
        showingPhotoPicker = false
    }

    private func deletePhoto() async {
        let vm = photoEditViewModel ?? container.makeProfileEditViewModel()
        photoEditViewModel = vm

        // Load profile
        await vm.loadProfile()

        // Delete all photos (we only support single photo)
        while !vm.photoUrls.isEmpty {
            await vm.deletePhoto(at: 0)
        }

        // Save profile
        _ = await vm.saveProfile()

        // Refresh view
        await viewModel.refresh()

        // Reset
        photoEditViewModel = nil
    }
}

// MARK: - Badge Explanation View

private struct BadgeExplanationView: View {
    let badgeName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Spacer()
                .frame(height: 20)

            // Content
            VStack(spacing: AppSpacing.lg) {
                // Icon & Title
                VStack(spacing: AppSpacing.sm) {
                    Text(badgeEmoji)
                        .font(.system(size: 48))

                    Text(badgeTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                // Description
                VStack(spacing: AppSpacing.md) {
                    Text(badgeDescription)
                        .font(AppTypography.bodyLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    // How to earn
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("How to earn:")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        Text(howToEarn)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(AppColors.primaryLight.opacity(0.1))
                    .cornerRadius(AppSpacing.radiusMedium)
                }
                .padding(.horizontal, AppSpacing.contentPadding)

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.top, AppSpacing.sm)
            }

            Spacer()
        }
        .presentationDetents([.height(450)])
        .presentationDragIndicator(.visible)
    }

    private var badgeEmoji: String {
        if badgeName.contains("⭐") { return "⭐" }
        if badgeName.contains("🕐") { return "🕐" }
        if badgeName.contains("🤝") { return "🤝" }
        if badgeName.contains("📊") { return "📊" }
        if badgeName.contains("💬") { return "💬" }
        return "🏆"
    }

    private var badgeTitle: String {
        if badgeName.contains("Trusted Regular") { return "Trusted Regular" }
        if badgeName.contains("On-Time") { return "On-Time" }
        if badgeName.contains("Respectful") { return "Respectful" }
        if badgeName.contains("Well-Matched") { return "Well-Matched" }
        if badgeName.contains("Clear Communicator") { return "Clear Communicator" }
        return "Badge"
    }

    private var badgeDescription: String {
        if badgeName.contains("Trusted Regular") {
            return "You're a consistent and reliable member of the TeePals community"
        }
        if badgeName.contains("On-Time") {
            return "You have a track record of showing up on time for rounds"
        }
        if badgeName.contains("Respectful") {
            return "Playing partners appreciate your positive attitude and respectful demeanor"
        }
        if badgeName.contains("Well-Matched") {
            return "Your stated skill level accurately reflects your actual play"
        }
        if badgeName.contains("Clear Communicator") {
            return "You communicate effectively with your playing partners"
        }
        return "Achievement badge"
    }

    private var howToEarn: String {
        if badgeName.contains("Trusted Regular") {
            return "Complete 20+ rounds with consistently positive feedback from playing partners"
        }
        if badgeName.contains("On-Time") {
            return "Receive positive feedback for punctuality from multiple playing partners"
        }
        if badgeName.contains("Respectful") {
            return "Maintain a respectful and positive attitude across multiple rounds"
        }
        if badgeName.contains("Well-Matched") {
            return "Playing partners confirm your skill level matches your actual play"
        }
        if badgeName.contains("Clear Communicator") {
            return "Receive positive feedback for communication from playing partners"
        }
        return "Complete rounds and receive positive feedback"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = AppContainer()
    ProfileView(
        viewModel: ProfileViewModel(
            profileRepository: ProfilePreviewMocks.repository,
            socialRepository: ProfilePreviewMocks.socialRepository,
            currentUid: { "preview-uid" }
        )
    )
    .environmentObject(container.authService)
    .environmentObject(container)
}

enum ProfilePreviewMocks {
    static let repository: ProfileRepository = MockProfileRepo()
    static let socialRepository: SocialRepository = MockSocialRepo()

    private class MockProfileRepo: ProfileRepository {
        func profileExists(uid: String) async throws -> Bool { true }
        func fetchPublicProfile(uid: String) async throws -> PublicProfile? {
            PublicProfile(
                id: uid, nickname: "GolfPro", gender: .male,
                occupation: "Software Engineer", bio: "Love hitting the links!",
                primaryCityLabel: "San Jose, CA",
                primaryLocation: GeoLocation(latitude: 37.3382, longitude: -121.8863),
                avgScore: 85, skillLevel: .intermediate, birthYear: 1992
            )
        }
        func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
        func upsertPublicProfile(_ profile: PublicProfile) async throws {}
        func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
    }

    private class MockSocialRepo: SocialRepository {
        func follow(targetUid: String) async throws {}
        func unfollow(targetUid: String) async throws {}
        func isFollowing(targetUid: String) async throws -> Bool { false }
        func isFollowedBy(targetUid: String) async throws -> Bool { false }
        func isMutualFollow(targetUid: String) async throws -> Bool { false }
        func getFollowing() async throws -> [String] { ["1", "2", "3"] }
        func getFollowers() async throws -> [String] { ["1", "2"] }
        func getFriends() async throws -> [String] { ["1"] }
        func getFollowerCount(uid: String) async throws -> Int { 42 }
        func getFollowingCount(uid: String) async throws -> Int { 18 }
        func fetchMutualFollows(uid: String) async throws -> [FollowUser] { [] }
        func areMutualFollows(uid1: String, uid2: String) async throws -> Bool { false }
        func fetchFollowersWithProfiles(uid: String) async throws -> [FollowUser] { [] }
        func fetchFollowingWithProfiles(uid: String) async throws -> [FollowUser] { [] }
    }
}
#endif
