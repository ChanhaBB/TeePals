import SwiftUI

/// Main container for the Tier 1 onboarding wizard (V3 Design).
/// Shows header with back button and step counter, current step content, and sticky bottom button.
struct Tier1OnboardingFlow: View {
    @StateObject private var viewModel: Tier1OnboardingViewModel
    @EnvironmentObject private var authService: AuthService

    init(viewModel: Tier1OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Background
            AppColorsV3.surfaceWhite
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (back button + step counter)
                headerView
                    .padding(.top, 56)
                    .padding(.bottom, 48)

                // Step content
                stepContent
                    .frame(maxHeight: .infinity, alignment: .top)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                // Sticky bottom button
                bottomButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    .padding(.top, 16)
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
        HStack {
            // Back button
            Button {
                if viewModel.currentStep == .name {
                    // Go back to onboarding carousel by signing out
                    authService.signOut()
                } else {
                    // Go to previous step
                    Task {
                        await viewModel.goBack()
                    }
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 24))
                    .foregroundColor(AppColorsV3.textPrimary)
                    .frame(width: 40, height: 40)
            }
            .padding(.leading, -8)

            Spacer()

            // Step counter
            Text("\(viewModel.currentStep.stepNumber)/\(Tier1OnboardingViewModel.OnboardingStep.totalSteps)")
                .font(AppTypographyV3.onboardingStepCounter)
                .tracking(2.0)
                .foregroundColor(AppColorsV3.forestGreen)

            Spacer()

            // Placeholder for symmetry
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .name:
            NameStepView(viewModel: viewModel)
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

    // MARK: - Bottom Button

    private var bottomButton: some View {
        PrimaryButtonV3(
            title: viewModel.isLastStep ? "Complete Setup" : "Continue",
            action: {
                Task {
                    await viewModel.goNext()
                }
            },
            isDisabled: !viewModel.isCurrentStepValid,
            isLoading: viewModel.isLoading
        )
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
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundStyle(AppColorsV3.textSecondary)
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

// MARK: - Preview

#if DEBUG
struct Tier1OnboardingFlow_Previews: PreviewProvider {
    static var previews: some View {
        let container = AppContainer()
        return Tier1OnboardingFlow(
            viewModel: Tier1OnboardingViewModel(
                profileRepository: MockProfileRepository(),
                currentUid: { "preview" }
            )
        )
        .environmentObject(container.authService)
    }
}

// Mock for previews
private class MockProfileRepository: ProfileRepository {
    func profileExists(uid: String) async throws -> Bool { false }
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}
#endif

