import SwiftUI

/// Profile View V3 - Redesigned with Instagram-inspired layout and V3 design system
/// Supports both own profile and other user profiles with conditional logic
struct ProfileViewV3: View {
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    // Modal states
    @State private var showingSignOutAlert = false
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    @State private var showReportConfirmation = false
    @State private var showBlockConfirmation = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteFinalConfirmation = false
    // item-based covers are more reliable than isPresented:Bool when the child
    // contains its own NavigationStack — setting item to nil is the unambiguous dismiss signal.
    // followListMode removed — followers/following now use NavigationLink push
    @State private var editProfileItem: EditProfileTrigger? // non-nil = show edit profile
    @State private var photoViewerItem: PhotoViewerItem?   // non-nil = show photo viewer
    @State private var selectedBadge: String?
    @State private var selectedTab: ProfileTab = .profile
    @State private var selectedRound: RoundDetailIdentifier?
    @State private var navigationPath = NavigationPath()

    // Edit ViewModel — kept alongside editProfileItem so it's ready when cover appears
    @State private var editProfileViewModel: ProfileEditViewModel?

    /// Pass `true` when the view is presented via fullScreenCover (not embedded in a tab bar).
    /// Ensures a back button is shown and the view creates its own NavigationStack.
    var isPresented: Bool = false

    /// Pass `true` when the view is pushed onto an existing NavigationStack (e.g. from FollowersListView).
    /// The parent NavigationStack provides the back button — no inner NavigationStack is created.
    var isPushed: Bool = false

    init(viewModel: ProfileViewModel, isPresented: Bool = false, isPushed: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.isPresented = isPresented
        self.isPushed = isPushed
    }

    var body: some View {
        Group {
            if viewModel.isOwnProfile && !isPresented && !isPushed {
                // Own profile in tab bar — owns its NavigationStack for followers/following push.
                NavigationStack(path: $navigationPath) {
                    profileBody
                        .toolbar(.hidden, for: .navigationBar)
                }
                // Path count drives tab bar visibility instantly — updates at the
                // start of push/pop animations, unlike onAppear/onDisappear.
                .onChange(of: navigationPath.count) { _, newCount in
                    container.tabBarState.isHidden = newCount > 0
                }
            } else if isPushed {
                // Pushed onto an existing NavigationStack (e.g. from FollowersListView).
                // The parent stack provides the back button — no inner NavigationStack needed.
                profileBody
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            menuButton
                        }
                    }
            } else {
                // Presented via fullScreenCover — needs its own NavigationStack + explicit back button.
                NavigationStack {
                    profileBody
                        .navigationTitle("")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    dismiss()
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppColorsV3.textPrimary)
                                }
                            }

                            ToolbarItem(placement: .navigationBarTrailing) {
                                menuButton
                            }
                        }
                }
            }
        }
        .task {
            await viewModel.loadProfile()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
            Task { await viewModel.forceRefresh() }
        }
        // Alerts and sheets
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) { authService.signOut() }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Report User", isPresented: $showReportAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Report", role: .destructive) {
                guard let targetUid = viewModel.uid ?? viewModel.publicProfile?.id else { return }
                Task {
                    do {
                        let report = Report(
                            reporterUid: container.currentUid ?? "",
                            reportedUid: targetUid,
                            reason: "User reported from profile"
                        )
                        try await container.reportRepository.submitReport(report: report)
                        showReportConfirmation = true
                    } catch {
                        print("Failed to submit report: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to report this user? Our team will review the report.")
        }
        .alert("Thank You", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your report has been submitted. We'll review it shortly.")
        }
        .alert("Block User", isPresented: $showBlockAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Block", role: .destructive) {
                guard let targetUid = viewModel.uid ?? viewModel.publicProfile?.id else { return }
                Task {
                    do {
                        try await container.reportRepository.blockUser(blockedUid: targetUid)
                        showBlockConfirmation = true
                    } catch {
                        print("Failed to block user: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to block this user? You won't see their content anymore.")
        }
        .alert("User Blocked", isPresented: $showBlockConfirmation) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("This user has been blocked.")
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showDeleteFinalConfirmation = true
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showDeleteFinalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete My Account", role: .destructive) {
                Task { await authService.deleteAccount() }
            }
        } message: {
            Text("Your profile, rounds, posts, and all data will be permanently removed. You will need to create a new account to use TeePals again.")
        }
        .overlay {
            if authService.isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: AppSpacingV3.md) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("Deleting account...")
                            .font(AppTypographyV3.bodySemibold)
                            .foregroundColor(.white)
                    }
                    .padding(AppSpacingV3.xl)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
        .fullScreenCover(item: $editProfileItem) { _ in
            if let editVM = editProfileViewModel {
                EditProfileSheet(viewModel: editVM) {
                    Task { await viewModel.refresh() }
                }
            }
        }
        .onChange(of: editProfileItem) { _, newValue in
            if newValue == nil { editProfileViewModel = nil }
        }
        .fullScreenCover(item: $photoViewerItem) { item in
            PhotoViewerView(photoUrls: item.urls, initialIndex: 0)
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeExplanationView(badgeName: badge)
        }
        .fullScreenCover(item: $selectedRound) { item in
            RoundDetailCover(roundId: item.roundId)
                .environmentObject(container)
        }
    }

    // MARK: - Profile Body

    private var profileBody: some View {
        // All navigationDestination registrations for this NavigationStack must live here —
        // at the root — and only when this view OWNS the stack (tab-bar root or isPresented cover).
        // isPushed views must NOT register any destinations; the root's registrations handle all
        // navigation regardless of stack depth, and duplicate registrations cause SwiftUI warnings.
        Group {
            if isPushed {
                profileBodyContent
            } else {
                profileBodyContent
                    // Follow list push. FollowListRequest carries the uid of the profile that
                    // was tapped — critical so the root destination uses the correct uid and not
                    // the root viewModel.uid (which would always show the current user's list).
                    .navigationDestination(for: FollowListRequest.self) { request in
                        FollowersListView(
                            uid: request.uid,
                            mode: request.mode == .followers ? .followers : .following,
                            currentUserUid: container.currentUid
                        )
                        .environmentObject(container)
                    }
                    // Profile push from within FollowersListView rows.
                    // Registered here (root) so FollowersListView itself never re-registers it.
                    .navigationDestination(for: String.self) { uid in
                        ProfileViewV3(
                            viewModel: container.makeProfileViewModel(uid: uid),
                            isPushed: true
                        )
                        .environmentObject(container)
                    }
            }
        }
    }

    private var profileBodyContent: some View {
        ZStack {
            AppColorsV3.bgNeutral.ignoresSafeArea()

            content
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
            VStack(spacing: AppSpacingV3.lg) {
                SkeletonCard(style: .profileCard)
            }
            .padding(AppSpacingV3.contentPadding)
        }
    }

    private var emptyState: some View {
        ScrollView {
            EmptyStateView.noProfile { /* No action */ }
                .padding(.top, AppSpacingV3.xl)
        }
    }

    private func errorState(_ message: String) -> some View {
        ScrollView {
            VStack {
                Spacer(minLength: AppSpacingV3.xxl)
                InlineErrorBanner(message, actionTitle: "Retry") {
                    viewModel.errorMessage = nil
                    Task { await viewModel.loadProfile() }
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
                Spacer()
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(profile: PublicProfile) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection(profile: profile)

                // Tab bar
                tabBar

                // Tab content
                tabContent(profile: profile)
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(
                tab: .profile,
                icon: "person.fill",
                label: "Profile"
            )

            tabButton(
                tab: .rounds,
                icon: "calendar",
                label: "Rounds"
            )
        }
        .background(AppColorsV3.bgNeutral)
        .overlay(
            Rectangle()
                .fill(AppColorsV3.borderLight)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func tabButton(tab: ProfileTab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(height: 24)
                    .foregroundColor(selectedTab == tab ? AppColorsV3.forestGreen : AppColorsV3.textSecondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())

                Rectangle()
                    .fill(selectedTab == tab ? AppColorsV3.forestGreen : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(profile: PublicProfile) -> some View {
        VStack(spacing: AppSpacingV3.lg) {
            switch selectedTab {
            case .profile:
                profileTabContent(profile: profile)
            case .rounds:
                roundsTabContent(profile: profile)
            }
        }
        .padding(AppSpacingV3.contentPadding)
        .padding(.bottom, 100)
    }

    private func profileTabContent(profile: PublicProfile) -> some View {
        Group {
            aboutMeCard(profile: profile)
            golfCard(profile: profile)
            if let instagram = profile.instagramUsername, !instagram.isEmpty {
                socialMediaCard(instagram: instagram)
            }
        }
    }

    @ViewBuilder
    private func roundsTabContent(profile: PublicProfile) -> some View {
        Group {
            if !viewModel.hasAttemptedPastRoundsLoad || viewModel.isPastRoundsLoading {
                ProgressView()
                    .padding(.top, AppSpacingV3.xl)
            } else if viewModel.pastRounds.isEmpty {
                VStack(spacing: AppSpacingV3.md) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 48))
                        .foregroundColor(AppColorsV3.textSecondary.opacity(0.5))

                    Text(viewModel.isOwnProfile ? "No past rounds yet" : "No past rounds")
                        .font(AppTypographyV3.headlineMedium)
                        .foregroundColor(AppColorsV3.textPrimary)

                    Text(viewModel.isOwnProfile ? "Rounds you've played will appear here" : "This user hasn't played any rounds yet")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppSpacingV3.xl)
            } else {
                VStack(spacing: AppSpacingV3.gapSmall) {
                    ForEach(viewModel.pastRounds) { item in
                        CompactRoundCard(
                            dateMonth: pastRoundMonthAbbrev(item.round.startTime),
                            dateDay: pastRoundDayOfMonth(item.round.startTime),
                            courseName: item.round.displayCourseName.compactCourseName(),
                            hostName: item.hostProfile?.nickname ?? "Host",
                            hostPhotoURL: item.hostProfile?.photoUrls.first.flatMap { URL(string: $0) },
                            distance: "",
                            statusBadge: item.role == .hosting ? "Hosted" : "Played",
                            isUserRound: item.role == .hosting,
                            showSlots: false,
                            action: {
                                if let roundId = item.round.id {
                                    selectedRound = RoundDetailIdentifier(roundId: roundId)
                                }
                            }
                        )
                    }
                }
            }
        }
        // Single task — only fires once when this content first appears.
        .task {
            guard !viewModel.hasAttemptedPastRoundsLoad, !viewModel.isPastRoundsLoading else { return }
            await viewModel.loadPastRounds()
        }
    }

    private func pastRoundMonthAbbrev(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    private func pastRoundDayOfMonth(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    // MARK: - Header Section

    private func headerSection(profile: PublicProfile) -> some View {
        VStack(spacing: AppSpacingV3.md) {
            // Photo + Name/Stats (horizontal layout, left-aligned)
            HStack(alignment: .center, spacing: AppSpacingV3.lg) {
                // Profile photo with verified badge
                Button {
                    if !profile.photoUrls.isEmpty {
                        photoViewerItem = PhotoViewerItem(urls: profile.photoUrls)
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        photoDisplay(profile: profile)

                        // Verified badge (green checkmark for trusted users)
                        if profile.trustTier != .rookie {
                            Circle()
                                .fill(AppColorsV3.forestGreen)
                                .frame(width: 26, height: 26)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(AppColorsV3.bgNeutral, lineWidth: 2)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(profile.photoUrls.isEmpty)

                // Name + Stats (vertical stack on right side)
                VStack(alignment: .leading, spacing: AppSpacingV3.xs) {
                    // Name (smaller font, with fallback to nickname)
                    Text(displayNameForHeader(profile: profile))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColorsV3.textPrimary)

                    // Stats (horizontal row, left-aligned with more spacing)
                    HStack(spacing: AppSpacingV3.xl) {
                        statItem(
                            count: profile.completedRoundsCount,
                            label: "rounds"
                        )

                        if let uid = viewModel.uid {
                            NavigationLink(value: FollowListRequest(uid: uid, mode: .followers)) {
                                statContent(count: viewModel.followerCount, label: "followers")
                            }
                            .buttonStyle(.plain)

                            NavigationLink(value: FollowListRequest(uid: uid, mode: .following)) {
                                statContent(count: viewModel.followingCount, label: "following")
                            }
                            .buttonStyle(.plain)
                        } else {
                            statContent(count: viewModel.followerCount, label: "followers")
                            statContent(count: viewModel.followingCount, label: "following")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Bio, location, Instagram (left-aligned)
            bioSection(profile: profile)

            // Action buttons (conditional based on own vs other profile)
            actionButtons(profile: profile)
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
        // When inside a NavigationStack (presented or pushed) the nav bar provides top spacing.
        // The large headerTop padding is only needed for the tab-bar (non-presented/pushed) layout.
        .padding(.top, (isPresented || isPushed) ? AppSpacingV3.sm : AppSpacingV3.headerTop)
        .padding(.bottom, AppSpacingV3.md)
        .background(AppColorsV3.bgNeutral)
        .overlay(
            // Overlay menu button only in tab-bar mode (own profile, not in any NavigationStack).
            // When presented or pushed, the toolbar already shows the menu button.
            Group {
                if viewModel.isOwnProfile && !isPresented && !isPushed {
                    VStack {
                        HStack {
                            Spacer()
                            menuButton
                                .padding(.trailing, AppSpacingV3.contentPadding)
                        }
                        Spacer()
                    }
                }
            }
        )
    }

    private func photoDisplay(profile: PublicProfile) -> some View {
        TPAvatar(
            url: profile.photoUrls.first.flatMap { URL(string: $0) },
            size: 86
        )
        .overlay(
            Circle()
                .stroke(AppColorsV3.forestGreen.opacity(0.3), lineWidth: 2)
        )
    }

    private func displayNameForHeader(profile: PublicProfile) -> String {
        // Use fullName which already handles fallback to nickname for legacy users
        profile.fullName
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(profile: PublicProfile) -> some View {
        if viewModel.isOwnProfile {
            Button {
                editProfileViewModel = container.makeProfileEditViewModel()
                editProfileItem = EditProfileTrigger()
            } label: {
                Text("Edit Profile")
                    .font(AppTypographyV3.bodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(AppColorsV3.forestGreen)
                    .cornerRadius(8)
            }
        } else {
            // Other profile: Follow button
            followButton
        }
    }

    private var followButton: some View {
        Button {
            Task {
                await viewModel.toggleFollow()
            }
        } label: {
            HStack(spacing: 6) {
                if viewModel.isMutualFollow {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                    Text("Friends")
                } else if viewModel.isFollowing {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14))
                    Text("Following")
                } else if viewModel.isFollowedByThem {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.system(size: 14))
                    Text("Follow Back")
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                    Text("Follow")
                }
            }
            .font(AppTypographyV3.bodySemibold)
            .foregroundColor(viewModel.isFollowing || viewModel.isMutualFollow ? AppColorsV3.textPrimary : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(viewModel.isFollowing || viewModel.isMutualFollow ? AppColorsV3.surfaceLight : AppColorsV3.forestGreen)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.isFollowing || viewModel.isMutualFollow ? AppColorsV3.borderLight : Color.clear, lineWidth: 1)
            )
        }
    }

    private func statItem(count: Int, label: String, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action = action {
                Button(action: action) {
                    statContent(count: count, label: label)
                }
                .buttonStyle(.plain)
            } else {
                statContent(count: count, label: label)
            }
        }
    }

    private func statContent(count: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppColorsV3.textPrimary)

            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(AppColorsV3.textSecondary)
        }
    }

    // MARK: - Bio Section

    private func bioSection(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Location
            if !profile.primaryCityLabel.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AppColorsV3.textSecondary)

                    Text(profile.primaryCityLabel)
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - About Me Card

    private func aboutMeCard(profile: PublicProfile) -> some View {
        aboutMeCardContent(profile: profile)
    }

    private func aboutMeCardContent(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.md) {
            SectionLabelV3(title: "Personal Info", size: 11)

            VStack(alignment: .leading, spacing: 0) {
                if let age = viewModel.age {
                    profileInfoCell(icon: "birthday.cake", label: "Age", value: "\(age)", isFirst: true)
                    if let gender = profile.gender, gender != .preferNot {
                        profileInfoCell(icon: "person", label: "Gender", value: gender.displayText)
                    }
                    if let occupation = profile.occupation, !occupation.isEmpty {
                        profileInfoCell(icon: "briefcase.fill", label: "Occupation", value: occupation)
                    }
                } else if let gender = profile.gender, gender != .preferNot {
                    profileInfoCell(icon: "person", label: "Gender", value: gender.displayText, isFirst: true)
                    if let occupation = profile.occupation, !occupation.isEmpty {
                        profileInfoCell(icon: "briefcase.fill", label: "Occupation", value: occupation)
                    }
                } else if let occupation = profile.occupation, !occupation.isEmpty {
                    profileInfoCell(icon: "briefcase.fill", label: "Occupation", value: occupation, isFirst: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColorsV3.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Golf Card

    private func golfCard(profile: PublicProfile) -> some View {
        golfCardContent(profile: profile)
    }

    private func golfCardContent(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.md) {
            SectionLabelV3(title: "Golf Profile", size: 11)

            VStack(alignment: .leading, spacing: 0) {
                if let skill = profile.skillLevel {
                    profileInfoCell(icon: "figure.golf", label: "Skill Level", value: skill.displayText, isFirst: true)
                    if let score = profile.avgScore {
                        profileInfoCell(icon: "chart.bar", label: "Avg Score", value: "\(score)+")
                    }
                    if let plays = profile.playsPerMonth {
                        profileInfoCell(icon: "calendar", label: "Plays / Month", value: "\(plays)x / month")
                    }
                } else if let score = profile.avgScore {
                    profileInfoCell(icon: "chart.bar", label: "Avg Score", value: "\(score)+", isFirst: true)
                    if let plays = profile.playsPerMonth {
                        profileInfoCell(icon: "calendar", label: "Plays / Month", value: "\(plays)x / month")
                    }
                } else if let plays = profile.playsPerMonth {
                    profileInfoCell(icon: "calendar", label: "Plays / Month", value: "\(plays)x / month", isFirst: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColorsV3.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Social Media Card

    private func socialMediaCard(instagram: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.md) {
            SectionLabelV3(title: "Social Media", size: 11)

            Button {
                let handle = instagram.hasPrefix("@") ? String(instagram.dropFirst()) : instagram
                if let url = URL(string: "https://instagram.com/\(handle)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                profileInfoRow(icon: "camera", label: "Instagram", value: "@\(instagram.hasPrefix("@") ? String(instagram.dropFirst()) : instagram)")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColorsV3.borderLight, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    /// Wraps a row with a leading-inset divider above it (skip for first row).
    /// Inset = icon width (24) + HStack spacing (md) — card outer padding already accounts for the left margin.
    private func profileInfoCell(icon: String, label: String, value: String, isFirst: Bool = false) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider()
                    .padding(.leading, 24 + AppSpacingV3.md)
            }
            profileInfoRow(icon: icon, label: label, value: value)
        }
    }

    private func profileInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: AppSpacingV3.md) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppColorsV3.forestGreen)
                .frame(width: 24)

            Text(label)
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textPrimary)

            Spacer()

            Text(value)
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, AppSpacingV3.sm)
    }

    // MARK: - Badges Card

    private func badgesCard(profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            Text("ACHIEVEMENTS")
                .font(AppTypographyV3.labelUppercaseBold)
                .foregroundColor(AppColorsV3.textSecondary)
                .tracking(0.2)

            if profile.earnedBadges.isEmpty {
                Text("Play more rounds to unlock badges!")
                    .font(AppTypographyV3.bodyMedium)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(profile.earnedBadges, id: \.self) { badge in
                        Button {
                            selectedBadge = badge
                        } label: {
                            HStack(spacing: 10) {
                                Text(badge)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppColorsV3.textPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Play again stat
                    if profile.shouldShowPlayAgainStat {
                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 8) {
                            Text("Would Play Again:")
                                .font(AppTypographyV3.bodyMedium)
                                .foregroundColor(AppColorsV3.textSecondary)
                            Text("\(Int(profile.recentWouldPlayAgainPct * 100))%")
                                .font(AppTypographyV3.bodyMedium)
                                .foregroundColor(AppColorsV3.success)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacingV3.lg)
        .background(AppColorsV3.surfaceWhite)
        .cornerRadius(12)
    }

    // MARK: - Posts Button

    private var myPostsButton: some View {
        NavigationLink {
            if let uid = viewModel.uid {
                PostsListScreen(uid: uid)
                    .environmentObject(container)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.isOwnProfile ? "My Posts" : "Posts")
                        .font(AppTypographyV3.headlineMedium)
                        .foregroundColor(AppColorsV3.textPrimary)

                    Text(viewModel.isOwnProfile ? "Posts you've shared" : "Posts from this user")
                        .font(AppTypographyV3.caption)
                        .foregroundColor(AppColorsV3.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(AppColorsV3.textSecondary)
            }
            .padding(AppSpacingV3.lg)
            .background(AppColorsV3.surfaceWhite)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu

    private var menuButton: some View {
        Menu {
            if viewModel.isOwnProfile {
                Button("Sign Out", role: .destructive) {
                    showingSignOutAlert = true
                }
                Button("Delete Account", role: .destructive) {
                    showDeleteAccountAlert = true
                }
            } else {
                Button("Report", role: .destructive) {
                    showReportAlert = true
                }
                Button("Block", role: .destructive) {
                    showBlockAlert = true
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColorsV3.textPrimary)
                .frame(width: 40, height: 40)
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Button {
            showingSignOutAlert = true
        } label: {
            HStack(spacing: AppSpacingV3.xs) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14))
                Text("Sign Out")
            }
            .font(AppTypographyV3.bodyMedium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacingV3.sm)
            .foregroundColor(AppColorsV3.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Profile Tab Enum

enum ProfileTab {
    case profile
    case rounds
}

// MARK: - Follow List Mode

enum FollowListMode: String, Identifiable, Hashable {
    case followers
    case following
    var id: String { rawValue }
}

/// Carries both the target uid AND mode so the root NavigationStack destination
/// handler always opens the correct profile's follow list, not the root's.
struct FollowListRequest: Hashable {
    let uid: String
    let mode: FollowListMode
}

// MARK: - Photo Viewer Item

private struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let urls: [String]
}

/// Token used to drive the edit-profile fullScreenCover via item: binding.
private struct EditProfileTrigger: Identifiable, Equatable {
    let id = UUID()
}

// MARK: - Badge Explanation View (reused from ProfileView)

private struct BadgeExplanationView: View {
    let badgeName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)

            VStack(spacing: AppSpacingV3.lg) {
                // Icon & Title
                VStack(spacing: AppSpacingV3.sm) {
                    Text(badgeEmoji)
                        .font(.system(size: 48))

                    Text(badgeTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColorsV3.textPrimary)
                }

                // Description
                VStack(spacing: AppSpacingV3.md) {
                    Text(badgeDescription)
                        .font(AppTypographyV3.bodyLarge)
                        .foregroundColor(AppColorsV3.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: AppSpacingV3.xs) {
                        Text("How to earn:")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColorsV3.textPrimary)

                        Text(howToEarn)
                            .font(AppTypographyV3.bodyMedium)
                            .foregroundColor(AppColorsV3.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacingV3.md)
                    .background(AppColorsV3.forestGreen.opacity(0.1))
                    .cornerRadius(AppSpacingV3.radiusMedium)
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColorsV3.forestGreen)
                        .cornerRadius(12)
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
                .padding(.top, AppSpacingV3.sm)
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
struct ProfileViewV3_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        NavigationStack {
            ProfileViewV3(
                viewModel: ProfileViewModel(
                    profileRepository: ProfileV3PreviewMocks.repository,
                    socialRepository: ProfileV3PreviewMocks.socialRepository,
                    activityService: ProfileV3PreviewMocks.activityService,
                    roundsRepository: ProfileV3PreviewMocks.roundsRepository,
                    currentUid: { "preview-uid" }
                )
            )
            .environmentObject(container.authService)
            .environmentObject(container)
        }
    }
}

enum ProfileV3PreviewMocks {
    static let repository: ProfileRepository = MockProfileRepo()
    static let socialRepository: SocialRepository = MockSocialRepo()
    static let activityService: ActivityRoundsService = MockActivityService()
    static let roundsRepository: RoundsRepository = MockRoundsRepo()

    private class MockRoundsRepo: RoundsRepository {
        func createRound(_ round: Round) async throws -> Round { round }
        func fetchRound(id: String) async throws -> Round? { nil }
        func fetchRounds(filters: RoundFilters, limit: Int, lastRound: Round?) async throws -> [Round] { [] }
        func updateRound(_ round: Round) async throws {}
        func cancelRound(id: String) async throws {}
        func fetchMembers(roundId: String) async throws -> [RoundMember] { [] }
        func requestToJoin(roundId: String) async throws {}
        func joinRound(roundId: String) async throws {}
        func acceptMember(roundId: String, memberUid: String) async throws {}
        func declineMember(roundId: String, memberUid: String) async throws {}
        func removeMember(roundId: String, memberUid: String) async throws {}
        func leaveRound(roundId: String) async throws {}
        func inviteMember(roundId: String, targetUid: String) async throws {}
        func fetchMembershipStatus(roundId: String) async throws -> RoundMember? { nil }
        func fetchInvitedRounds() async throws -> [Round] { [] }
        func acceptInvite(roundId: String) async throws {}
        func declineInvite(roundId: String) async throws {}
    }

    private class MockActivityService: ActivityRoundsService {
        func fetchHostingRounds(dateRange: DateRangeOption?, includeCompleted: Bool) async throws -> [Round] { [] }
        func fetchRequestedRounds(dateRange: DateRangeOption?) async throws -> [RoundRequest] { [] }
        func fetchParticipatedRounds(for uid: String, dateRange: DateRangeOption?) async throws -> [RoundRequest] { [] }
        func fetchViewerMemberRoundIds() async throws -> Set<String> { [] }
    }

    private class MockProfileRepo: ProfileRepository {
        func profileExists(uid: String) async throws -> Bool { true }
        func fetchPublicProfile(uid: String) async throws -> PublicProfile? {
            PublicProfile(
                id: uid,
                nickname: "GolfPro",
                gender: .male,
                bio: "Weekend warrior looking to break 85 consistently. Love early morning tee times.",
                primaryCityLabel: "San Diego, CA",
                primaryLocation: GeoLocation(latitude: 32.7157, longitude: -117.1611),
                avgScore: 85,
                skillLevel: .intermediate,
                birthYear: 1990,
                completedRoundsCount: 24
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
        func getFollowerCount(uid: String) async throws -> Int { 1200 }
        func getFollowingCount(uid: String) async throws -> Int { 156 }
        func fetchMutualFollows(uid: String) async throws -> [FollowUser] { [] }
        func areMutualFollows(uid1: String, uid2: String) async throws -> Bool { false }
        func fetchFollowersWithProfiles(uid: String) async throws -> [FollowUser] { [] }
        func fetchFollowingWithProfiles(uid: String) async throws -> [FollowUser] { [] }
    }
}
#endif
