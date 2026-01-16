import SwiftUI

/// Main container for the Tier 1 onboarding wizard.
/// Shows progress, current step, and navigation controls.
struct Tier1OnboardingFlow: View {
    @StateObject private var viewModel: Tier1OnboardingViewModel
    @EnvironmentObject private var authService: AuthService
    
    init(viewModel: Tier1OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with progress
                headerView
                
                // Step content
                stepContent
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                
                // Navigation buttons
                navigationButtons
            }
            
            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .alert("Error", isPresented: showingError, presenting: viewModel.errorMessage) { _ in
            Button("OK") { viewModel.errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            if isComplete {
                authService.completeProfileSetup()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(Tier1OnboardingViewModel.OnboardingStep.allCases, id: \.self) { step in
                    ProgressDot(
                        isCompleted: step.rawValue < viewModel.currentStep.rawValue,
                        isCurrent: step == viewModel.currentStep
                    )
                }
            }
            .padding(.top, 16)
            
            // Step counter
            Text("Step \(viewModel.currentStep.stepNumber) of \(Tier1OnboardingViewModel.OnboardingStep.totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .nickname:
            NicknameStepView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .birthdate:
            BirthdateStepView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .location:
            LocationStepView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .gender:
            GenderStepView(viewModel: viewModel)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            // Back button
            if viewModel.canGoBack {
                Button {
                    viewModel.goBack()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
            
            // Next/Finish button
            Button {
                Task {
                    await viewModel.goNext()
                }
            } label: {
                HStack {
                    Text(viewModel.isLastStep ? "Finish" : "Next")
                    if !viewModel.isLastStep {
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    viewModel.isCurrentStepValid
                        ? Color(red: 0.1, green: 0.45, blue: 0.25)
                        : Color(.systemGray4)
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!viewModel.isCurrentStepValid)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Saving...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Error Binding
    
    private var showingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Progress Dot

struct ProgressDot: View {
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: isCurrent ? 12 : 8, height: isCurrent ? 12 : 8)
            .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }
    
    private var fillColor: Color {
        if isCompleted {
            return Color(red: 0.1, green: 0.45, blue: 0.25)
        } else if isCurrent {
            return Color(red: 0.1, green: 0.45, blue: 0.25)
        } else {
            return Color(.systemGray4)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct Tier1OnboardingFlow_Previews: PreviewProvider {
    static var previews: some View {
        Tier1OnboardingFlow(
            viewModel: Tier1OnboardingViewModel(
                profileRepository: MockProfileRepository(),
                currentUid: { "preview" }
            )
        )
        .environmentObject(AuthService())
    }
}

// Mock for previews
private class MockProfileRepository: ProfileRepository {
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}
#endif

