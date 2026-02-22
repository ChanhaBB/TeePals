import SwiftUI

/// Activity view — chip-based navigation: Schedule | Invites (n) | Past.
struct ActivityRoundsViewV2: View {

    @ObservedObject var viewModel: ActivityRoundsViewModelV2

    let onRoundTap: (Round) -> Void
    let onCreateRound: () -> Void
    let onSwitchToNearby: () -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasLoadedOnce {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.isEmpty {
                errorState(error)
            } else {
                contentView
            }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        ScrollView {
            VStack(spacing: AppSpacingV3.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCard(style: .roundCard)
                }
            }
            .padding(.horizontal, AppSpacingV3.contentPadding)
            .padding(.top, AppSpacingV3.sm)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        ScrollView {
            VStack {
                Spacer(minLength: 48)
                InlineErrorBanner(message, actionTitle: "Retry") {
                    Task { await viewModel.loadActivity() }
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
                Spacer()
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView {
            VStack(spacing: AppSpacingV3.md) {
                tabContent
            }
            .padding(.horizontal, AppSpacingV3.contentPadding)
            .padding(.top, AppSpacingV3.xs)
            .padding(.bottom, 100)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .schedule:
            scheduleContent
        case .invites:
            invitesContent
        case .pending:
            pendingContent
        case .past:
            pastContent
        }
    }

    // MARK: - Schedule Tab

    @ViewBuilder
    private var scheduleContent: some View {
        let rounds = viewModel.scheduleRounds
        if rounds.isEmpty {
            scheduleEmptyState
        } else {
            ForEach(rounds) { item in
                scheduleCard(for: item)
            }
        }
    }

    private func scheduleCard(for item: ActivityRoundItem) -> some View {
        CompactRoundCard(
            dateMonth: monthAbbrev(item.round.startTime),
            dateDay: dayOfMonth(item.round.startTime),
            courseName: item.round.displayCourseName.compactCourseName(),
            hostName: item.hostProfile?.nickname ?? "Host",
            hostPhotoURL: item.hostProfile?.photoUrls.first.flatMap { URL(string: $0) },
            distance: distanceToRound(item.round),
            statusBadge: item.role == .hosting ? "Hosting" : nil,
            showNotificationDot: item.role == .hosting && item.round.requestCount > 0,
            isUserRound: item.isConfirmedOrHosting,
            showSlots: false,
            action: { onRoundTap(item.round) }
        )
    }

    // MARK: - Invites Tab

    @ViewBuilder
    private var invitesContent: some View {
        let invites = viewModel.inviteRounds
        if invites.isEmpty {
            invitesEmptyState
        } else {
            ForEach(invites) { item in
                inviteCard(for: item)
            }
        }
    }

    private func inviteCard(for item: ActivityRoundItem) -> some View {
        let hostName = item.hostProfile?.displayName ?? item.inviterName ?? "Host"
        let hostPhoto = item.hostProfile?.photoUrls.first ?? item.inviterPhotoURL

        return ActivityInviteCard(
            dateMonth: monthAbbrev(item.round.startTime),
            dateDay: dayOfMonth(item.round.startTime),
            courseName: item.round.displayCourseName.compactCourseName(),
            inviterName: hostName,
            inviterPhotoURL: hostPhoto.flatMap(URL.init),
            onTap: { onRoundTap(item.round) },
            onAccept: {
                Task {
                    if let roundId = item.round.id {
                        await viewModel.acceptInvite(roundId: roundId)
                    }
                }
            },
            onDecline: {
                Task {
                    if let roundId = item.round.id {
                        await viewModel.declineInvite(roundId: roundId)
                    }
                }
            }
        )
    }

    // MARK: - Pending Tab

    @ViewBuilder
    private var pendingContent: some View {
        let rounds = viewModel.pendingRounds
        if rounds.isEmpty {
            pendingEmptyState
        } else {
            ForEach(rounds) { item in
                CompactRoundCard(
                    dateMonth: monthAbbrev(item.round.startTime),
                    dateDay: dayOfMonth(item.round.startTime),
                    courseName: item.round.displayCourseName.compactCourseName(),
                    hostName: item.hostProfile?.nickname ?? "Host",
                    hostPhotoURL: item.hostProfile?.photoUrls.first.flatMap { URL(string: $0) },
                    distance: distanceToRound(item.round),
                    statusBadge: "Awaiting Host",
                    isUserRound: false,
                    showSlots: false,
                    action: { onRoundTap(item.round) }
                )
            }
        }
    }

    // MARK: - Past Tab

    @ViewBuilder
    private var pastContent: some View {
        let rounds = viewModel.pastRounds
        if rounds.isEmpty {
            pastEmptyState
        } else {
            ForEach(rounds) { item in
                CompactRoundCard(
                    dateMonth: monthAbbrev(item.round.startTime),
                    dateDay: dayOfMonth(item.round.startTime),
                    courseName: item.round.displayCourseName.compactCourseName(),
                    hostName: item.hostProfile?.nickname ?? "Host",
                    hostPhotoURL: item.hostProfile?.photoUrls.first.flatMap { URL(string: $0) },
                    distance: distanceToRound(item.round),
                    isUserRound: false,
                    showSlots: false,
                    action: { onRoundTap(item.round) }
                )
            }
        }
    }

    // MARK: - Schedule Empty State

    private var scheduleEmptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColorsV3.forestGreen.opacity(0.05))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image(systemName: "calendar")
                            .font(.system(size: 36))
                            .foregroundColor(AppColorsV3.forestGreen.opacity(0.4))
                    )

                Circle()
                    .fill(AppColorsV3.surfaceWhite)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().stroke(AppColorsV3.borderLight, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "calendar.badge.minus")
                            .font(.system(size: 18))
                            .foregroundColor(AppColorsV3.forestGreen)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    .offset(x: 8, y: 8)
            }
            .padding(.bottom, 32)

            Text("No upcoming rounds")
                .font(.custom("PlayfairDisplay-Regular", size: 24, relativeTo: .title))
                .fontWeight(.bold)
                .foregroundColor(AppColorsV3.forestGreen)
                .padding(.bottom, 12)

            Text("Host a round or find one nearby to get started.")
                .font(AppTypographyV3.bodyRegular)
                .foregroundColor(AppColorsV3.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .padding(.bottom, 40)

            Button(action: onSwitchToNearby) {
                Text("Find a Round")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 16)
                    .background(AppColorsV3.forestGreen)
                    .cornerRadius(AppSpacingV3.radiusButton)
                    .shadow(color: AppColorsV3.forestGreen.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)

            Button(action: onCreateRound) {
                Text("Host a Round")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundColor(AppColorsV3.forestGreen)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    // MARK: - Invites Empty State

    private var invitesEmptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            Circle()
                .fill(Color.gray.opacity(0.04))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "envelope")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(Color.gray.opacity(0.3))
                )
                .padding(.bottom, 24)

            Text("No pending invites")
                .font(.custom("PlayfairDisplay-Regular", size: 24, relativeTo: .title))
                .fontWeight(.bold)
                .foregroundColor(AppColorsV3.textPrimary)
                .padding(.bottom, 8)

            Text("When someone invites you to a round, you'll see it here.")
                .font(AppTypographyV3.bodyRegular)
                .foregroundColor(AppColorsV3.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    // MARK: - Past Empty State

    private var pastEmptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            Circle()
                .fill(AppColorsV3.forestGreen.opacity(0.05))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "trophy")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(AppColorsV3.forestGreen.opacity(0.3))
                )
                .padding(.bottom, 24)

            Text("No past rounds yet")
                .font(.custom("PlayfairDisplay-Regular", size: 24, relativeTo: .title))
                .fontWeight(.bold)
                .foregroundColor(AppColorsV3.textPrimary)
                .padding(.bottom, 12)

            Text("Your completed rounds and scores will appear here after you play.")
                .font(AppTypographyV3.bodyRegular)
                .foregroundColor(AppColorsV3.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    // MARK: - Pending Empty State

    private var pendingEmptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)

            Circle()
                .fill(Color.gray.opacity(0.04))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "hourglass")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(Color.gray.opacity(0.3))
                )
                .padding(.bottom, 24)

            Text("No pending requests")
                .font(.custom("PlayfairDisplay-Regular", size: 24, relativeTo: .title))
                .fontWeight(.bold)
                .foregroundColor(AppColorsV3.textPrimary)
                .padding(.bottom, 8)

            Text("When you request to join a round, it will appear here until the host responds.")
                .font(AppTypographyV3.bodyRegular)
                .foregroundColor(AppColorsV3.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    // MARK: - Date Helpers

    private func monthAbbrev(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    private func dayOfMonth(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func distanceToRound(_ round: Round) -> String {
        guard let userLocation = viewModel.currentUserProfile?.primaryLocation,
              let geo = round.geo else { return "" }
        let miles = DistanceUtil.haversineMiles(
            lat1: userLocation.latitude, lng1: userLocation.longitude,
            lat2: geo.lat, lng2: geo.lng
        )
        return String(format: "%.1fmi", miles)
    }
}
