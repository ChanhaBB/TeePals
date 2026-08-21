import SwiftUI

/// 4-step wizard for creating a new round.
/// Steps: Course → Date/Time → Details → Review
struct CreateRoundFlow: View {
    @StateObject private var viewModel: CreateRoundViewModel
    @StateObject private var courseSearchService = GolfCourseSearchService()
    @EnvironmentObject var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    
    var onSuccess: ((Round) -> Void)?
    
    init(viewModel: CreateRoundViewModel, onSuccess: ((Round) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            progressBar
            header
            stepContent
            footerButtons
        }
        .background(AppColorsV3.bgNeutral.ignoresSafeArea())
        .disabled(viewModel.isSaving)
        .onChange(of: viewModel.currentStep) { _, newStep in
            if newStep == .review {
                Task { await viewModel.loadCoursePhoto(using: container.coursePhotoService) }
            }
        }
        .alert("Error", isPresented: showingError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Drag Handle
    
    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(AppColorsV3.surfaceWhite)
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColorsV3.borderLight)
                Rectangle()
                    .fill(AppColorsV3.forestGreen)
                    .frame(width: geo.size.width * viewModel.progress)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
            }
        }
        .frame(height: 3)
    }
    
    // MARK: - Header (Cancel + Title/Step indicator)

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColorsV3.textPrimary)
            }

            Spacer()

            if !viewModel.isEditMode {
                Text("Step \(viewModel.currentStep.stepNumber) of \(CreateRoundStep.totalSteps)")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.15 * 11)
                    .foregroundColor(AppColorsV3.textSecondary)
            }
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
        .padding(.vertical, AppSpacingV3.md)
        .background(AppColorsV3.surfaceWhite)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id("top")
                    
                    Group {
                        switch viewModel.currentStep {
                        case .course:
                            CreateRoundCourseStep(
                                viewModel: viewModel,
                                searchService: courseSearchService
                            )
                        case .dateTime:
                            CreateRoundDateTimeStep(viewModel: viewModel)
                        case .settings:
                            CreateRoundSettingsStep(viewModel: viewModel)
                        case .review:
                            CreateRoundReviewStep(viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, AppSpacingV3.contentPadding)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.currentStep) { _, _ in
                withAnimation {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
    }
    
    // MARK: - Footer (Back + Next/Post)
    
    private var footerButtons: some View {
        HStack(spacing: AppSpacingV3.sm) {
            if viewModel.canGoBack {
                Button {
                    viewModel.goBack()
                } label: {
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColorsV3.textSecondary)
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .background(AppColorsV3.borderLight)
                        .cornerRadius(24)
                }
                .buttonStyle(.plain)
            }
            
            if viewModel.isLastStep {
                PrimaryButtonV3(
                    title: viewModel.isEditMode ? "Save Changes" : "Post Round",
                    action: {
                        Task {
                            if await viewModel.createRound() {
                                if let round = viewModel.createdRound {
                                    onSuccess?(round)
                                }
                                dismiss()
                            }
                        }
                    },
                    isDisabled: !viewModel.isCurrentStepValid,
                    isLoading: viewModel.isSaving
                )
            } else {
                PrimaryButtonV3(
                    title: "Next",
                    action: { viewModel.goNext() },
                    isDisabled: !viewModel.isCurrentStepValid
                )
            }
        }
        .padding(.horizontal, AppSpacingV3.contentPadding)
        .padding(.top, AppSpacingV3.sm)
        .padding(.bottom, AppSpacingV3.lg)
        .background(
            AppColorsV3.surfaceWhite
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: -2)
        )
    }
    
    // MARK: - Error Binding
    
    private var showingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    CreateRoundFlow(
        viewModel: CreateRoundViewModel(
            roundsRepository: MockRoundsRepository(),
            currentUid: { "preview" }
        )
    )
}

private class MockRoundsRepository: RoundsRepository {
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
#endif
