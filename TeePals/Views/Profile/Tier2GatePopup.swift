import SwiftUI

/// Modal popup shown when user attempts a Tier 2 gated action.
/// Title: "Complete your profile"
/// Body: Shows what's missing (photo + skill level)
/// Buttons: "Complete now" → ProfileEdit, "Not now" → dismiss
struct Tier2GatePopup: View {
    @ObservedObject var coordinator: ProfileGateCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            handleBar
            
            // Content
            VStack(spacing: AppSpacing.lg) {
                iconSection
                textSection
                requirementsSection
                buttonsSection
            }
            .padding(AppSpacing.contentPadding)
        }
        .background(AppColors.backgroundPrimary)
    }
    
    // MARK: - Handle Bar
    
    private var handleBar: some View {
        Capsule()
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
    }
    
    // MARK: - Icon
    
    private var iconSection: some View {
        Image(systemName: "person.crop.circle.badge.plus")
            .font(.system(size: 56))
            .foregroundStyle(AppColors.primary)
    }
    
    // MARK: - Text
    
    private var textSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Complete your profile")
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Add at least 1 photo to unlock this feature.")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Requirements
    
    private var requirementsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(coordinator.missingTier2Requirements, id: \.self) { req in
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: req.systemImage)
                        .font(.body)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 24)
                    
                    Text(req.displayName)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "circle")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .padding(AppSpacing.md)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(AppRadii.card)
            }
        }
    }
    
    // MARK: - Buttons
    
    private var buttonsSection: some View {
        VStack(spacing: AppSpacing.sm) {
            PrimaryButton("Complete now") {
                coordinator.completeNowTapped()
                dismiss()
            }
            
            TextButton("Not now") {
                coordinator.notNowTapped()
                dismiss()
            }
        }
        .padding(.top, AppSpacing.sm)
    }
}

// MARK: - Tier 2 Gate Modifier

/// ViewModifier that presents the Tier 2 gate popup and handles navigation.
/// Apply at the root (TabView or NavigationStack) to enable gating everywhere.
struct Tier2GateModifier: ViewModifier {
    @ObservedObject var coordinator: ProfileGateCoordinator
    let makeProfileEditView: () -> AnyView
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $coordinator.isGatePresented) {
                Tier2GatePopup(coordinator: coordinator)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $coordinator.isProfileEditPresented) {
                makeProfileEditView()
            }
    }
}

extension View {
    /// Applies Tier 2 gating behavior to this view.
    /// - Parameters:
    ///   - coordinator: The gate coordinator to use
    ///   - profileEditView: Factory for the profile edit view
    func tier2Gated(
        coordinator: ProfileGateCoordinator,
        profileEditView: @escaping () -> AnyView
    ) -> some View {
        modifier(Tier2GateModifier(
            coordinator: coordinator,
            makeProfileEditView: profileEditView
        ))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    Tier2GatePopup(
        coordinator: ProfileGateCoordinator(
            profileRepository: PreviewMocks.profileRepository,
            currentUid: { "preview" }
        )
    )
}

private enum PreviewMocks {
    static let profileRepository: ProfileRepository = MockRepo()
    
    private class MockRepo: ProfileRepository {
    func profileExists(uid: String) async throws -> Bool { false }
        func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
        func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
        func upsertPublicProfile(_ profile: PublicProfile) async throws {}
        func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
    }
}
#endif

