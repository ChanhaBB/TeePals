import SwiftUI

/// Detail view for a single round - shows course, time, host, members, and actions.
struct RoundDetailView: View {
    @StateObject private var viewModel: RoundDetailViewModel
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCancelAlert = false
    @State private var showingLeaveAlert = false
    @State private var showingCancelRequestAlert = false
    @State private var showingEditRound = false
    @State private var showingChat = false
    @State private var showingInviteSheet = false
    @State private var selectedProfileUid: String?
    
    init(viewModel: RoundDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundGrouped.ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.round == nil {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.round == nil {
                errorView(error)
            } else if let round = viewModel.round {
                roundContent(round)
            }
        }
        .navigationTitle("Round Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Share button (for host and members who can share)
                if viewModel.canShare {
                    Button {
                        Task { await viewModel.generateShareLink() }
                    } label: {
                        if viewModel.isGeneratingLink {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .offset(x: 2.5, y: -2.5)
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
        .sheet(isPresented: $showingEditRound) {
            if let round = viewModel.round {
                EditRoundView(
                    round: round,
                    roundsRepository: container.roundsRepository,
                    onSave: { updatedRound in
                        // Immediately update local state with the saved round
                        viewModel.updateRound(updatedRound)
                    }
                )
            }
        }
        .sheet(item: $selectedProfileUid) { uid in
            OtherUserProfileView(viewModel: container.makeOtherUserProfileViewModel(uid: uid))
        }
        .sheet(isPresented: $showingChat) {
            NavigationStack {
                RoundChatView(viewModel: container.makeRoundChatViewModel(roundId: viewModel.roundId))
                    .environmentObject(container)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { showingChat = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteUsersSheet(
                viewModel: container.makeInviteUsersViewModel(roundId: viewModel.roundId)
            )
        }
    }
    
    // MARK: - Request Pending Banner

    private var requestPendingBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(AppColors.primary)

            Text("Your request is pending")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.primaryLight.opacity(0.3))
        .cornerRadius(AppSpacing.radiusMedium)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
    
    // MARK: - Error
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            SecondaryButton("Go Back") { dismiss() }
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Content
    
    private func roundContent(_ round: Round) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    RoundDetailHeader(round: round)

                    // Status banner for pending request
                    if viewModel.hasRequested {
                        requestPendingBanner
                    }

                    RoundDetailPlayersSection(
                        hostUid: round.hostUid,
                        hostProfile: viewModel.hostProfile,
                        members: viewModel.acceptedMembers,
                        profiles: viewModel.memberProfiles,
                        spotsRemaining: round.spotsRemaining,
                        maxPlayers: round.maxPlayers,
                        currentUserUid: container.currentUid,
                        isCurrentUserHost: viewModel.isHost,
                        canInvite: viewModel.canInvite,
                        onProfileTap: { uid in
                            selectedProfileUid = uid
                        },
                        onRemoveMember: { uid in
                            Task { await viewModel.removeMember(uid) }
                        },
                        onInvite: {
                            showingInviteSheet = true
                        }
                    )
                    
                    RoundDetailDescriptionSection(description: round.description)
                    
                    if viewModel.isHost && !viewModel.pendingRequests.isEmpty {
                        RoundDetailRequestsSection(
                            requests: viewModel.pendingRequests,
                            profiles: viewModel.memberProfiles,
                            onAccept: { uid in Task { await viewModel.acceptMember(uid) } },
                            onDecline: { uid in Task { await viewModel.declineMember(uid) } },
                            onProfileTap: { uid in selectedProfileUid = uid }
                        )
                    }
                    
                    RoundDetailInfoSection(round: round)
                }
                .padding(AppSpacing.contentPadding)
                .padding(.bottom, 100)
            }
            
            // Sticky bottom action
            bottomAction(round)
        }
    }
    
    // MARK: - Bottom Action
    
    @ViewBuilder
    private func bottomAction(_ round: Round) -> some View {
        VStack(spacing: AppSpacing.sm) {
            if let success = viewModel.successMessage {
                Text(success)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.success)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
            }
            
            if viewModel.isHost {
                SecondaryButton("Round Chat", icon: "bubble.left.and.bubble.right") {
                    showingChat = true
                }
            } else if viewModel.isMember {
                HStack(spacing: AppSpacing.md) {
                    SecondaryButton("Leave", icon: "arrow.left.circle") {
                        showingLeaveAlert = true
                    }
                    PrimaryButton("Chat", icon: "bubble.left") {
                        showingChat = true
                    }
                }
            } else if viewModel.hasRequested {
                // Only action in footer - status is in content
                SecondaryButton("Cancel Request", icon: "xmark.circle") {
                    showingCancelRequestAlert = true
                }
            } else if viewModel.canJoin {
                PrimaryButton(
                    round.joinPolicy == .instant ? "Join Round" : "Request to Join",
                    icon: round.joinPolicy == .instant ? "plus.circle" : "hand.raised",
                    isLoading: viewModel.isActioning
                ) {
                    Task {
                        let canProceed = await container.profileGateCoordinator.requireTier2Async()
                        if canProceed {
                            await viewModel.requestToJoin()
                        }
                    }
                }
            } else if round.isFull {
                SecondaryButton("Round Full", icon: "person.3.fill") {}
                    .disabled(true)
            } else if round.status != .open {
                SecondaryButton("Round \(round.status.displayText)", icon: "lock") {}
                    .disabled(true)
            }
        }
        .padding(AppSpacing.contentPadding)
        .background(
            AppColors.backgroundPrimary
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
    }
}

// MARK: - String Identifiable for Sheet

extension String: @retroactive Identifiable {
    public var id: String { self }
}
