import SwiftUI

/// V3 Round Detail View - Hero image design with streamlined layout
struct RoundDetailView: View {
    @StateObject private var viewModel: RoundDetailViewModel
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var showingCancelAlert = false
    @State private var showingLeaveAlert = false
    @State private var showingCancelRequestAlert = false
    @State private var showingDeclineInviteAlert = false
    @State private var showingMarkCompleteAlert = false
    @State private var showingEditRound = false
    @State private var showingChat = false
    @State private var showingInviteSheet = false
    @State private var showingFeedback = false
    @State private var selectedProfileUid: String?
    @State private var coursePhotoURL: URL?
    @State private var isLoadingPhoto = false
    @State private var memberToRemove: String?

    init(viewModel: RoundDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.round == nil {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.round == nil {
                errorView(error)
            } else if let round = viewModel.round {
                roundContent(round)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // Hide default back button to avoid conflicts
        .interactiveDismissDisabled(false) // Ensure dismiss works
        .toolbar {
            // Back button
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    print("🔙 Back button tapped") // Debug logging
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColorsV3.textPrimary)
                        .frame(width: 44, height: 44) // Larger tap target
                        .contentShape(Rectangle()) // Expand tap area
                }
                .highPriorityGesture(TapGesture().onEnded {
                    print("🔙 Back button tapped (high priority)")
                    dismiss()
                })
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Share button
                if viewModel.canShare {
                    Button {
                        Task { await viewModel.generateShareLink() }
                    } label: {
                        if viewModel.isGeneratingLink {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17))
                                .foregroundColor(AppColorsV3.textPrimary)
                        }
                    }
                    .disabled(viewModel.isGeneratingLink)
                }

                // Host actions menu
                if viewModel.isHost {
                    Menu {
                        Button {
                            showingEditRound = true
                        } label: {
                            Label("Edit Round", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingCancelAlert = true
                        } label: {
                            Label("Cancel Round", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                            .foregroundColor(AppColorsV3.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.shareURL {
                ShareSheet(items: [viewModel.shareMessage(), url])
            }
        }
        .task {
            await viewModel.loadRound()
            await loadCoursePhoto()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert("Cancel Round?", isPresented: $showingCancelAlert) {
            Button("Keep Round", role: .cancel) {}
            Button("Cancel Round", role: .destructive) {
                Task { await viewModel.cancelRound() }
            }
        } message: {
            Text("This will notify all members. This action cannot be undone.")
        }
        .alert("Leave Round?", isPresented: $showingLeaveAlert) {
            Button("Stay", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await viewModel.leaveRound() }
            }
        } message: {
            Text("You can request to rejoin later.")
        }
        .alert("Cancel Request?", isPresented: $showingCancelRequestAlert) {
            Button("Keep Request", role: .cancel) {}
            Button("Cancel Request", role: .destructive) {
                Task { await viewModel.cancelRequest() }
            }
        } message: {
            Text("You can request to join again later.")
        }
        .alert("Decline Invitation?", isPresented: $showingDeclineInviteAlert) {
            Button("Keep Invite", role: .cancel) {}
            Button("Decline", role: .destructive) {
                Task { await viewModel.declineInvite() }
            }
        } message: {
            Text("You can ask the host to re-invite you later.")
        }
        .sheet(isPresented: $showingMarkCompleteAlert) {
            MarkCompleteConfirmationView(
                onConfirm: {
                    showingMarkCompleteAlert = false
                    Task { await viewModel.markAsCompleted() }
                },
                onCancel: {
                    showingMarkCompleteAlert = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingEditRound) {
            if let round = viewModel.round {
                CreateRoundFlow(
                    viewModel: CreateRoundViewModel(
                        round: round,
                        roundsRepository: container.roundsRepository,
                        currentUid: container.currentUidProvider
                    ),
                    onSuccess: { updatedRound in
                        viewModel.updateRound(updatedRound)
                    }
                )
                .environmentObject(container)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(item: $selectedProfileUid) { uid in
            ProfileViewV3(viewModel: container.makeProfileViewModel(uid: uid), isPresented: true)
                .environmentObject(container)
        }
        .sheet(isPresented: $showingChat) {
            RoundChatView(viewModel: container.makeRoundChatViewModel(roundId: viewModel.roundId))
                .environmentObject(container)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteUsersSheet(
                viewModel: container.makeInviteUsersViewModel(roundId: viewModel.roundId)
            )
        }
        .sheet(isPresented: $showingFeedback) {
            PostRoundFeedbackView(
                viewModel: container.makePostRoundFeedbackViewModel(roundId: viewModel.roundId)
            )
        }
        .alert("Remove Player?", isPresented: .init(
            get: { memberToRemove != nil },
            set: { if !$0 { memberToRemove = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let uid = memberToRemove {
                    Task {
                        await viewModel.removeMember(uid)
                        memberToRemove = nil
                    }
                }
            }
        } message: {
            if let uid = memberToRemove,
               let profile = viewModel.memberProfiles[uid] {
                Text("Remove \(profile.displayName) from this round? They will be notified.")
            } else {
                Text("Remove this player from the round? They will be notified.")
            }
        }
    }

    // MARK: - Round Content

    private func roundContent(_ round: Round) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection(round)

                    VStack(spacing: AppSpacingV3.lg) {
                        // Status banners
                        if viewModel.hasRequested {
                            requestPendingBanner
                                .padding(.horizontal, AppSpacingV3.contentPadding)
                        }

                        if round.status == .completed && viewModel.isMember {
                            feedbackBanner
                                .padding(.horizontal, AppSpacingV3.contentPadding)
                        }

                        // Round info section
                        roundInfoSection(round)

                        // Players section
                        playersSection(round)

                        // Join requests (host only)
                        if viewModel.isHost && !viewModel.pendingRequests.isEmpty {
                            joinRequestsSection
                        }
                    }
                    .padding(.top, AppSpacingV3.lg)
                    .padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Bottom action bar
            bottomActionBar(round)
        }
    }

    // MARK: - Hero Section

    private func heroSection(_ round: Round) -> some View {
        ZStack(alignment: .topLeading) {
            // Course photo
            Color.clear
                .overlay {
                    if let photoURL = coursePhotoURL {
                        TPImage(url: photoURL)
                    } else {
                        Image("course-placeholder")
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()

            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.2), location: 0.4),
                    .init(color: .black.opacity(0.7), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Course info overlay (bottom)
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    // Status badge
                    statusBadge(round.status)
                        .padding(.bottom, 4)

                    // Course name
                    Text(round.displayCourseName)
                        .font(.custom("PlayfairDisplay-Regular", size: 30, relativeTo: .largeTitle))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                    // Location + distance
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                        Text(locationWithDistance(round))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)

                    // Date & Time pills
                    HStack(spacing: 12) {
                        if let teeTime = round.displayTeeTime {
                            HStack(spacing: 4) {
                                Text(formatDate(teeTime))
                                    .font(.system(size: 14, weight: .medium))
                                    .tracking(0.3)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.4))
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            )

                            HStack(spacing: 4) {
                                Text(formatTime(teeTime))
                                    .font(.system(size: 14, weight: .medium))
                                    .tracking(0.3)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.4))
                            .background(.ultraThinMaterial.opacity(0.6))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(height: 460)
    }

    private func statusBadge(_ status: RoundStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
            Text(status.displayText.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor(status))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    private func statusColor(_ status: RoundStatus) -> Color {
        switch status {
        case .open: return AppColorsV3.success
        case .closed: return AppColorsV3.forestGreen
        case .canceled: return AppColorsV3.error
        case .completed: return AppColorsV3.textSecondary
        }
    }

    // MARK: - Round Info Section

    private func roundInfoSection(_ round: Round) -> some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.md) {
            // Price & Visibility row
            HStack(spacing: 12) {
                // Always show price (even if TBD)
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 14))
                    if let price = round.price?.amount, price > 0 {
                        Text("$\(price)/person")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Text("Price TBD")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(AppColorsV3.forestGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColorsV3.forestGreen.opacity(0.08))
                .clipShape(Capsule())

                if round.visibility == .friends {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text("Friends Only")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppColorsV3.forestGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppColorsV3.forestGreen.opacity(0.08))
                    .clipShape(Capsule())
                }

                Spacer()
            }

            // Host message
            if let description = round.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
                    Text("MESSAGE FROM HOST")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(AppColorsV3.textSecondary.opacity(0.6))

                    Text(description)
                        .font(AppTypographyV3.bodyRegular)
                        .foregroundColor(AppColorsV3.textPrimary)
                        .lineSpacing(4)
                        .padding(AppSpacingV3.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColorsV3.surfaceWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                }
            }
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    // MARK: - Players Section

    private func playersSection(_ round: Round) -> some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            // Section header
            HStack {
                Text("PLAYERS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppColorsV3.textSecondary.opacity(0.6))
                Spacer()
                Text("\(viewModel.acceptedMembers.count)/\(round.maxPlayers)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColorsV3.textSecondary)
            }

            VStack(spacing: 0) {
                // Host row
                playerRow(
                    uid: round.hostUid,
                    profile: viewModel.hostProfile,
                    isHost: true,
                    canRemove: false
                )

                // Member rows
                ForEach(viewModel.acceptedMembers.filter { $0.uid != round.hostUid }, id: \.uid) { member in
                    Divider()
                        .padding(.leading, 60)

                    playerRow(
                        uid: member.uid,
                        profile: viewModel.memberProfiles[member.uid],
                        isHost: false,
                        canRemove: viewModel.isHost && member.uid != container.currentUid
                    )
                }

                // Empty spots
                ForEach(0..<round.spotsRemaining, id: \.self) { _ in
                    Divider()
                        .padding(.leading, 60)

                    emptySpotRow(round)
                }
            }
            .background(AppColorsV3.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    private func playerRow(uid: String, profile: PublicProfile?, isHost: Bool, canRemove: Bool) -> some View {
        HStack(spacing: 12) {
            // Avatar with host badge
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatarView(url: profile?.photoUrls.first, size: 44)

                if isHost {
                    Circle()
                        .fill(AppColorsV3.forestGreen)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile?.displayName ?? "Player")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColorsV3.textPrimary)

                    if uid == container.currentUid {
                        Text("(You)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColorsV3.forestGreen)
                    }
                }
            }

            Spacer()

            // Remove button (host only)
            if canRemove {
                Button {
                    memberToRemove = uid
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColorsV3.textSecondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColorsV3.textSecondary.opacity(0.3))
        }
        .padding(AppSpacingV3.md)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedProfileUid = uid
        }
    }

    private func emptySpotRow(_ round: Round) -> some View {
        Button {
            if viewModel.canInvite {
                showingInviteSheet = true
            }
        } label: {
            HStack(spacing: 12) {
                // Dashed circle with plus
                Circle()
                    .strokeBorder(
                        viewModel.canInvite ? AppColorsV3.forestGreen.opacity(0.3) : AppColorsV3.borderLight,
                        style: StrokeStyle(lineWidth: 2, dash: [4])
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                            .foregroundColor(viewModel.canInvite ? AppColorsV3.forestGreen : AppColorsV3.textSecondary.opacity(0.4))
                    )

                if viewModel.canInvite {
                    Text("Tap to invite")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColorsV3.forestGreen)
                } else {
                    Text("Open spot")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColorsV3.textSecondary)
                }

                Spacer()

                if viewModel.canInvite {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColorsV3.textSecondary.opacity(0.3))
                }
            }
            .padding(AppSpacingV3.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canInvite)
    }

    // MARK: - Join Requests Section

    private var joinRequestsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacingV3.sm) {
            HStack {
                Text("JOIN REQUESTS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(AppColorsV3.textSecondary.opacity(0.6))

                Text("\(viewModel.pendingRequests.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColorsV3.forestGreen)
                    .clipShape(Capsule())
            }

            VStack(spacing: 0) {
                ForEach(viewModel.pendingRequests, id: \.uid) { request in
                    requestRow(request)

                    if request.uid != viewModel.pendingRequests.last?.uid {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(AppColorsV3.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
    }

    private func requestRow(_ request: RoundMember) -> some View {
        HStack(spacing: 12) {
            ProfileAvatarView(
                url: viewModel.memberProfiles[request.uid]?.photoUrls.first,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.memberProfiles[request.uid]?.displayName ?? "Player")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColorsV3.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.declineMember(request.uid) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColorsV3.error)
                        .frame(width: 32, height: 32)
                        .background(AppColorsV3.error.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.acceptMember(request.uid) }
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColorsV3.success)
                        .frame(width: 32, height: 32)
                        .background(AppColorsV3.success.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacingV3.md)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedProfileUid = request.uid
        }
    }

    // MARK: - Banners

    private var requestPendingBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColorsV3.warning)

            Text("Your request is pending")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColorsV3.textPrimary)

            Spacer()
        }
        .padding(AppSpacingV3.md)
        .background(AppColorsV3.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var feedbackBanner: some View {
        Button {
            showingFeedback = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColorsV3.success)

                Text("This round is complete. Rate your playing partners")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColorsV3.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColorsV3.textSecondary)
            }
            .padding(AppSpacingV3.md)
            .background(AppColorsV3.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Action Bar

    @ViewBuilder
    private func bottomActionBar(_ round: Round) -> some View {
        VStack(spacing: AppSpacingV3.sm) {
            if let success = viewModel.successMessage {
                Text(success)
                    .font(.system(size: 12))
                    .foregroundColor(AppColorsV3.success)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(AppColorsV3.error)
            }

            if viewModel.isHost {
                if round.status == .completed {
                    actionButton(
                        title: "Round Chat",
                        icon: "bubble.left.and.bubble.right.fill",
                        style: .secondary,
                        action: { showingChat = true }
                    )
                } else {
                    HStack(spacing: 12) {
                        actionButton(
                            title: "Round Chat",
                            icon: "bubble.left.and.bubble.right.fill",
                            style: .secondary,
                            action: { showingChat = true }
                        )
                        actionButton(
                            title: "Mark Complete",
                            icon: "checkmark.circle.fill",
                            style: .primary,
                            action: { showingMarkCompleteAlert = true }
                        )
                    }
                }
            } else if viewModel.isMember {
                HStack(spacing: 12) {
                    actionButton(
                        title: "Leave",
                        icon: "arrow.left.circle.fill",
                        style: .secondary,
                        action: { showingLeaveAlert = true }
                    )
                    actionButton(
                        title: "Chat",
                        icon: "bubble.left.fill",
                        style: .primary,
                        action: { showingChat = true }
                    )
                }
            } else if viewModel.hasRequested {
                actionButton(
                    title: "Cancel Request",
                    icon: "xmark.circle.fill",
                    style: .secondary,
                    action: { showingCancelRequestAlert = true }
                )
            } else if viewModel.isInvited {
                HStack(spacing: 12) {
                    actionButton(
                        title: "Decline",
                        icon: "xmark.circle.fill",
                        style: .secondary,
                        action: { showingDeclineInviteAlert = true }
                    )
                    actionButton(
                        title: "Accept Invite",
                        icon: "checkmark.circle.fill",
                        style: .primary,
                        isLoading: viewModel.isActioning,
                        action: {
                            Task {
                                let canProceed = await container.profileGateCoordinator.requireTier2Async()
                                if canProceed {
                                    await viewModel.acceptInvite()
                                }
                            }
                        }
                    )
                }
            } else if viewModel.canJoin {
                actionButton(
                    title: round.joinPolicy == .instant ? "Join Round" : "Request to Join",
                    icon: round.joinPolicy == .instant ? "plus.circle.fill" : "hand.raised.fill",
                    style: .primary,
                    isLoading: viewModel.isActioning,
                    action: {
                        Task {
                            let canProceed = await container.profileGateCoordinator.requireTier2Async()
                            if canProceed {
                                await viewModel.requestToJoin()
                            }
                        }
                    }
                )
            } else if round.isFull {
                actionButton(
                    title: "Round Full",
                    icon: "person.3.fill",
                    style: .disabled,
                    action: {}
                )
            } else if round.status != .open {
                actionButton(
                    title: "Round \(round.status.displayText)",
                    icon: "lock.fill",
                    style: .disabled,
                    action: {}
                )
            }
        }
        .padding(AppSpacingV3.contentPadding)
        .background(
            AppColorsV3.surfaceWhite
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private enum ButtonStyle {
        case primary, secondary, disabled
    }

    private func actionButton(
        title: String,
        icon: String,
        style: ButtonStyle,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : AppColorsV3.forestGreen)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(foregroundColor(style))
            .background(backgroundColor(style))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(
                color: style == .primary ? AppColorsV3.forestGreen.opacity(0.2) : .clear,
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(style == .disabled || isLoading)
    }

    private func foregroundColor(_ style: ButtonStyle) -> Color {
        switch style {
        case .primary: return .white
        case .secondary: return AppColorsV3.forestGreen
        case .disabled: return AppColorsV3.textSecondary
        }
    }

    private func backgroundColor(_ style: ButtonStyle) -> Color {
        switch style {
        case .primary: return AppColorsV3.forestGreen
        case .secondary: return AppColorsV3.forestGreen.opacity(0.08)
        case .disabled: return AppColorsV3.borderLight
        }
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacingV3.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(AppColorsV3.error)
            Text(message)
                .font(AppTypographyV3.bodyRegular)
                .foregroundColor(AppColorsV3.textSecondary)
            Button("Go Back") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColorsV3.forestGreen)
                .clipShape(Capsule())
            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func locationWithDistance(_ round: Round) -> String {
        // Calculate distance if user profile and round geo are available
        if let userProfile = viewModel.currentUserProfile,
           let geo = round.geo {
            let userLocation = userProfile.primaryLocation
            let miles = DistanceUtil.haversineMiles(
                lat1: userLocation.latitude, lng1: userLocation.longitude,
                lat2: geo.lat, lng2: geo.lng
            )
            return String(format: "%@ • %.1f mi", round.displayCityLabel, miles)
        }
        return round.displayCityLabel
    }

    private func loadCoursePhoto() async {
        guard let course = viewModel.round?.chosenCourse ?? viewModel.round?.courseCandidates.first else {
            return
        }

        guard !isLoadingPhoto else { return }
        isLoadingPhoto = true

        coursePhotoURL = await container.coursePhotoService?.fetchPhotoURL(for: course)
        isLoadingPhoto = false
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - String Identifiable for Sheet

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Mark Complete Confirmation View

private struct MarkCompleteConfirmationView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)

            VStack(spacing: AppSpacingV3.lg) {
                Text("Ready to wrap up the round?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColorsV3.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacingV3.contentPadding)

                Text("This will mark the round as complete.")
                    .font(.system(size: 15))
                    .foregroundColor(AppColorsV3.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacingV3.contentPadding)

                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Finish round")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColorsV3.success)
                        .cornerRadius(12)
                    }

                    Button(action: onCancel) {
                        Text("Do this later")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColorsV3.textSecondary)
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, AppSpacingV3.contentPadding)
                .padding(.top, AppSpacingV3.sm)
            }

            Spacer()
        }
    }
}
