import SwiftUI

/// View for editing an existing round.
struct EditRoundView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditRoundViewModel
    @StateObject private var courseSearchService = GolfCourseSearchService()
    
    let onSave: (Round) -> Void
    
    init(round: Round, roundsRepository: RoundsRepository, onSave: @escaping (Round) -> Void) {
        _viewModel = StateObject(wrappedValue: EditRoundViewModel(
            round: round,
            roundsRepository: roundsRepository
        ))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            EditRoundCourseSection(
                                viewModel: viewModel,
                                searchService: courseSearchService
                            )
                            EditRoundDateSection(preferredDate: $viewModel.preferredDate)
                            EditRoundVisibilitySection(visibility: $viewModel.visibility)
                            EditRoundPriceSection(priceAmount: $viewModel.priceAmount)
                            EditRoundPreferredTeePalsSection(
                                minAge: $viewModel.minAge,
                                maxAge: $viewModel.maxAge,
                                selectedSkillLevels: $viewModel.selectedSkillLevels
                            )
                            EditRoundMessageSection(message: $viewModel.hostMessage)
                        }
                        .padding(AppSpacing.contentPadding)
                        .padding(.bottom, 100)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    
                    saveButton
                }
            }
            .navigationTitle("Edit Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var saveButton: some View {
        VStack(spacing: AppSpacing.sm) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
            }
            
            PrimaryButton("Save Changes", isLoading: viewModel.isSaving) {
                Task {
                    if let updatedRound = await viewModel.saveRound() {
                        onSave(updatedRound)
                        dismiss()
                    }
                }
            }
            .disabled(!viewModel.canSave)
        }
        .padding(AppSpacing.contentPadding)
        .background(
            AppColors.backgroundPrimary
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
    }
}
