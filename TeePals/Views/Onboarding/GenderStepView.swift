import SwiftUI

/// Step 4: Gender selection for Tier 1 onboarding (V3 Design)
struct GenderStepView: View {
    @ObservedObject var viewModel: Tier1OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Title and subtitle
            VStack(alignment: .leading, spacing: 12) {
                Text("How do you identify?")
                    .font(AppTypographyV3.onboardingTitle)
                    .foregroundColor(AppColorsV3.forestGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("This helps build diverse groups")
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 40)

            // Gender Options
            VStack(spacing: 16) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    GenderOptionCardV3(
                        gender: gender,
                        isSelected: viewModel.gender == gender,
                        action: { viewModel.gender = gender }
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Gender Option Card (V3 Design)

private struct GenderOptionCardV3: View {
    let gender: Gender
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                // Label
                Text(gender.displayText)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColorsV3.textPrimary)

                Spacer()

                // Radio circle
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? AppColorsV3.forestGreen : Color.gray.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(AppColorsV3.forestGreen)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColorsV3.forestGreen.opacity(0.05) : AppColorsV3.surfaceWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? AppColorsV3.forestGreen : Color.gray.opacity(0.2),
                        lineWidth: isSelected ? 1 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
struct GenderStepView_Previews: PreviewProvider {
    static var previews: some View {
        GenderStepView(
            viewModel: Tier1OnboardingViewModel(
                profileRepository: PreviewMockProfileRepository(),
                currentUid: { "preview" }
            )
        )
    }
}

private class PreviewMockProfileRepository: ProfileRepository {
    func profileExists(uid: String) async throws -> Bool { false }
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}
#endif

