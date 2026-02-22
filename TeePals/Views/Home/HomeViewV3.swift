import SwiftUI

/// Home View V3 - Redesigned home dashboard matching premium HTML design
/// Uses UIFoundationNew V3 components and design system
struct HomeViewV3: View {

    @StateObject private var viewModel: HomeViewModel
    @ObservedObject var activityViewModel: ActivityRoundsViewModelV2
    @EnvironmentObject var container: AppContainer
    @EnvironmentObject var deepLinkCoordinator: DeepLinkCoordinator
    @Binding var selectedTab: Int
    @State private var roundDetail: RoundDetailIdentifier?

    init(viewModel: HomeViewModel, activityViewModel: ActivityRoundsViewModelV2, selectedTab: Binding<Int>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _activityViewModel = ObservedObject(wrappedValue: activityViewModel)
        _selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            AppColorsV3.bgNeutral
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection

                    welcomeSection
                        .padding(.top, AppSpacingV3.md)
                        .padding(.bottom, AppSpacingV3.sectionSpacing)

                    heroSection
                        .padding(.bottom, AppSpacingV3.sectionSpacing)

                    metricsSection
                        .padding(.bottom, AppSpacingV3.sectionSpacing)

                    myScheduleSection
                        .padding(.bottom, AppSpacingV3.sectionSpacing)

                    discoverRoundsSection
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 128)
            }
        }
        .task {
            async let dashboard: () = viewModel.loadDashboard()
            async let activity: () = activityViewModel.loadActivity()
            _ = await (dashboard, activity)

            if let firstRound = activityViewModel.scheduleRounds.first {
                await viewModel.loadCoursePhoto(for: firstRound.round)
            }
        }
        .refreshable {
            async let dashboard: () = viewModel.refresh()
            async let activity: () = activityViewModel.refresh()
            _ = await (dashboard, activity)

            if let firstRound = activityViewModel.scheduleRounds.first {
                await viewModel.loadCoursePhoto(for: firstRound.round)
            }
        }
        .fullScreenCover(item: $roundDetail) { item in
            RoundDetailCover(roundId: item.roundId)
                .environmentObject(container)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentDateText.uppercased())
                    .font(AppTypographyV3.labelUppercaseBold)
                    .tracking(0.2)
                    .foregroundColor(AppColorsV3.textSecondary)

                Text(greetingText)
                    .font(AppTypographyV3.displayLargeSerif)
                    .foregroundColor(AppColorsV3.forestGreen)
            }

            Spacer()

            if let photoUrlString = viewModel.userProfile?.photoUrls.first,
               let photoUrl = URL(string: photoUrlString) {
                TPAvatar(url: photoUrl, size: 40)
                    .overlay(
                        Circle()
                            .stroke(AppColorsV3.forestGreen.opacity(0.1), lineWidth: 2)
                    )
                    .padding(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacingV3.contentPadding)
        .padding(.top, AppSpacingV3.headerTop)
        .padding(.bottom, AppSpacingV3.headerBottom)
    }

    // MARK: - Welcome Section

    private var welcomeSection: some View {
        HStack {
            Text("Welcome back, ")
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textSecondary)
            +
            Text("\(viewModel.userProfile?.nickname ?? "Golfer")")
                .font(AppTypographyV3.bodySemibold)
                .foregroundColor(AppColorsV3.textPrimary)
            +
            Text(".")
                .font(AppTypographyV3.bodyMedium)
                .foregroundColor(AppColorsV3.textSecondary)

            Spacer()
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
        .padding(.top, 4)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        Group {
            if let firstSchedule = activityViewModel.scheduleRounds.first {
                HeroCardV3(
                    backgroundImage: viewModel.nextRoundPhotoURL,
                    assetImageName: viewModel.nextRoundPhotoURL == nil ? "course-placeholder" : nil,
                    badgeText: "Upcoming Round",
                    title: firstSchedule.round.displayCourseName.compactCourseName(),
                    subtitle: firstSchedule.round.displayDateTime ?? "",
                    buttonTitle: "View Details",
                    action: {
                        if let roundId = firstSchedule.round.id {
                            navigateToRoundDetail(roundId)
                        }
                    }
                )
            } else {
                HeroCardV3(
                    assetImageName: "course-placeholder",
                    title: "No Upcoming Rounds",
                    subtitle: "Your next tee time awaits",
                    buttonTitle: "Find a Round",
                    isEmptyState: true,
                    action: {
                        selectedTab = 1
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        HStack(spacing: AppSpacingV3.gapSmall) {
            MetricCardV3(
                icon: "envelope.fill",
                count: activityViewModel.inviteCount,
                label: "Invites",
                action: {
                    deepLinkCoordinator.navigateToActivityTab(.invites)
                    selectedTab = 1
                }
            )

            MetricCardV3(
                icon: "hourglass",
                count: activityViewModel.pendingCount,
                label: "Pending",
                action: {
                    deepLinkCoordinator.navigateToActivityTab(.pending)
                    selectedTab = 1
                }
            )
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    // MARK: - My Schedule Section

    private var myScheduleSection: some View {
        let scheduleItems = activityViewModel.scheduleRounds

        return VStack(spacing: AppSpacingV3.gapSmall) {
            SectionHeaderV3(
                title: "My Schedule",
                actionTitle: scheduleItems.isEmpty ? nil : "View All",
                action: {
                    deepLinkCoordinator.navigateToActivityTab(.schedule)
                    selectedTab = 1
                }
            )
            .padding(.horizontal, AppSpacingV3.contentPadding)

            if scheduleItems.isEmpty {
                HStack {
                    Text("Rounds you are participating in will appear here.")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
                .padding(.vertical, 4)
            } else {
                VStack(spacing: AppSpacingV3.gapSmall) {
                    ForEach(scheduleItems.prefix(3)) { item in
                        CompactRoundCard(
                            dateMonth: monthAbbreviation(from: item.round.startTime),
                            dateDay: dayOfMonth(from: item.round.startTime),
                            courseName: item.round.displayCourseName.compactCourseName(),
                            hostName: item.hostProfile?.nickname ?? "Host",
                            hostPhotoURL: item.hostProfile?.photoUrls.first.flatMap { URL(string: $0) },
                            distance: distanceToRound(item.round),
                            statusBadge: scheduleStatusBadge(for: item),
                            showNotificationDot: showNotificationDot(for: item),
                            isUserRound: item.isConfirmedOrHosting,
                            showSlots: false,
                            action: {
                                if let roundId = item.round.id {
                                    navigateToRoundDetail(roundId)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
            }
        }
    }

    // MARK: - Discover Rounds Section

    private var discoverRoundsSection: some View {
        VStack(spacing: AppSpacingV3.gapSmall) {
            SectionHeaderV3(
                title: "Discover Rounds",
                actionTitle: "View All",
                action: {
                    selectedTab = 1
                }
            )
            .padding(.horizontal, AppSpacingV3.contentPadding)

            if viewModel.nearbyRounds.isEmpty {
                HStack {
                    Text("No nearby rounds found. Host a round!")
                        .font(AppTypographyV3.bodyMedium)
                        .foregroundColor(AppColorsV3.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
                .padding(.vertical, 4)
            } else {
                VStack(spacing: AppSpacingV3.gapSmall) {
                    ForEach(viewModel.nearbyRounds.prefix(2), id: \.id) { round in
                        let hostProfile = viewModel.hostProfiles[round.hostUid]
                        CompactRoundCard(
                            dateMonth: monthAbbreviation(from: round.startTime),
                            dateDay: dayOfMonth(from: round.startTime),
                            courseName: round.displayCourseName.compactCourseName(),
                            hostName: hostProfile?.nickname ?? "Host",
                            hostPhotoURL: hostProfile?.photoUrls.first.flatMap { URL(string: $0) },
                            distance: formatDistance(round.distanceMiles),
                            totalSlots: round.maxPlayers,
                            filledSlots: round.acceptedCount,
                            isUserRound: false,
                            action: {
                                if let roundId = round.id {
                                    navigateToRoundDetail(roundId)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
            }
        }
    }

    // MARK: - Navigation

    private func navigateToRoundDetail(_ roundId: String) {
        roundDetail = RoundDetailIdentifier(roundId: roundId)
    }

    // MARK: - Schedule Badge Logic

    private func scheduleStatusBadge(for item: ActivityRoundItem) -> String? {
        item.role == .hosting ? "Hosting" : nil
    }

    private func showNotificationDot(for item: ActivityRoundItem) -> Bool {
        item.role == .hosting && item.round.requestCount > 0
    }

    // MARK: - Computed Properties

    private var currentDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }

    private var greetingText: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let hour = calendar.component(.hour, from: Date())

        let dayName: String
        switch weekday {
        case 1: dayName = "Sunday"
        case 2: dayName = "Monday"
        case 3: dayName = "Tuesday"
        case 4: dayName = "Wednesday"
        case 5: dayName = "Thursday"
        case 6: dayName = "Friday"
        case 7: dayName = "Saturday"
        default: dayName = "Day"
        }

        let timeOfDay: String
        if hour < 12 {
            timeOfDay = "Morning"
        } else if hour < 18 {
            timeOfDay = "Afternoon"
        } else {
            timeOfDay = "Evening"
        }

        return "\(dayName) \(timeOfDay)"
    }

    // MARK: - Helper Functions

    private func monthAbbreviation(from date: Date?) -> String {
        guard let date = date else { return "Jan" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func dayOfMonth(from date: Date?) -> String {
        guard let date = date else { return "1" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func formatDistance(_ miles: Double?) -> String {
        guard let miles = miles else { return "" }
        return String(format: "%.1fmi", miles)
    }

    private func distanceToRound(_ round: Round) -> String {
        guard let userLocation = viewModel.userProfile?.primaryLocation,
              let geo = round.geo else { return "" }
        let miles = DistanceUtil.haversineMiles(
            lat1: userLocation.latitude, lng1: userLocation.longitude,
            lat2: geo.lat, lng2: geo.lng
        )
        return String(format: "%.1fmi", miles)
    }
}

// MARK: - Preview

#if DEBUG
struct HomeViewV3_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        HomeViewV3(
            viewModel: container.makeHomeViewModel(),
            activityViewModel: container.sharedActivityViewModel,
            selectedTab: .constant(0)
        )
        .environmentObject(container)
    }
}
#endif
