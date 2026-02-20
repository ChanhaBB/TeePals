import SwiftUI

/// Step 2: Birthdate entry for Tier 1 onboarding (V3 Design)
struct BirthdateStepView: View {
    @ObservedObject var viewModel: Tier1OnboardingViewModel

    /// Minimum date: 100 years ago
    private var minDate: Date {
        Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
    }

    /// Maximum date: Must be 18+ years old
    private var maxDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    }

    /// Default selection: 25 years ago
    private var defaultDate: Date {
        Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 0) {
                Text("When's your birthday?")
                    .font(AppTypographyV3.onboardingTitle)
                    .foregroundColor(AppColorsV3.forestGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 48)

            Spacer()

            // Date Picker (centered vertically)
            VStack(spacing: 32) {
                DatePicker(
                    "Birth Date",
                    selection: birthDateBinding,
                    in: minDate...maxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                // Helper text
                Text("We keep this private (age verification only)")
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Computed Properties

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.birthDate ?? defaultDate },
            set: { viewModel.birthDate = $0 }
        )
    }
}

#if DEBUG
struct BirthdateStepView_Previews: PreviewProvider {
    static var previews: some View {
        BirthdateStepView(
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

