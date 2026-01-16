import SwiftUI

/// Simplified 4-step wizard for creating a new round.
/// Steps: Course → Date/Time → Details → Review
struct CreateRoundFlow: View {
    @StateObject private var viewModel: CreateRoundViewModel
    @StateObject private var courseSearchService = GolfCourseSearchService()
    @Environment(\.dismiss) private var dismiss
    
    var onSuccess: ((Round) -> Void)?
    
    init(viewModel: CreateRoundViewModel, onSuccess: ((Round) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    progressBar
                    stepContent
                    navigationButtons
                }
            }
            .navigationTitle(viewModel.currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .disabled(viewModel.isSaving)
            .alert("Error", isPresented: showingError) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack {
                Text("Step \(viewModel.currentStep.stepNumber) of \(CreateRoundStep.totalSteps)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.backgroundSecondary)
                    Rectangle()
                        .fill(AppColors.primary)
                        .frame(width: geo.size.width * viewModel.progress)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
        .padding(.top, AppSpacing.sm)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Anchor at top for scroll reset
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
                        case .details:
                            CreateRoundDetailsStep(viewModel: viewModel)
                        case .review:
                            CreateRoundReviewStep(viewModel: viewModel)
                        }
                    }
                    .padding(AppSpacing.contentPadding)
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
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            // Primary action
            if viewModel.isLastStep {
                PrimaryButton("Post Round", isLoading: viewModel.isSaving) {
                    Task {
                        if await viewModel.createRound() {
                            if let round = viewModel.createdRound {
                                onSuccess?(round)
                            }
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.isCurrentStepValid)
            } else {
                PrimaryButton("Next") {
                    viewModel.goNext()
                }
                .disabled(!viewModel.isCurrentStepValid)
            }
            
            // Secondary back action - subtle text style
            if viewModel.canGoBack {
                Button {
                    viewModel.goBack()
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
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
