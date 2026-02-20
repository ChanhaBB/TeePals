import SwiftUI

/// Step 1: First name and last name entry for Tier 1 onboarding (V3 Design)
struct NameStepView: View {
    @ObservedObject var viewModel: Tier1OnboardingViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case firstName
        case lastName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            VStack(alignment: .leading, spacing: 0) {
                Text("What is your name?")
                    .font(AppTypographyV3.onboardingTitle)
                    .foregroundColor(AppColorsV3.forestGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 48)

            // Input Fields
            VStack(alignment: .leading, spacing: 24) {
                // First Name Field
                UnderlineTextField(
                    placeholder: "First Name",
                    text: $viewModel.firstName,
                    isFocused: focusedField == .firstName,
                    onFocus: { focusedField = .firstName },
                    onBlur: { if focusedField == .firstName { focusedField = nil } }
                )
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .lastName
                }
                .focused($focusedField, equals: .firstName)

                // Last Name Field
                UnderlineTextField(
                    placeholder: "Last Name",
                    text: $viewModel.lastName,
                    isFocused: focusedField == .lastName,
                    onFocus: { focusedField = .lastName },
                    onBlur: { if focusedField == .lastName { focusedField = nil } }
                )
                .textContentType(.familyName)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
                .focused($focusedField, equals: .lastName)

                // Helper text
                Text("This will be used for your tee time reservations and profile.")
                    .font(AppTypographyV3.onboardingSubtitle)
                    .foregroundColor(AppColorsV3.textSecondary)
                    .padding(.top, 12)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }
}

/// Underline-style text field for onboarding (matches HTML design)
private struct UnderlineTextField: View {
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool
    let onFocus: () -> Void
    let onBlur: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $text, onEditingChanged: { editing in
                if editing {
                    onFocus()
                } else {
                    onBlur()
                }
            })
            .font(AppTypographyV3.onboardingInputLarge)
            .foregroundColor(AppColorsV3.textPrimary)
            .padding(.vertical, 16)
            .padding(.horizontal, 0)
            .accentColor(AppColorsV3.forestGreen)

            // Bottom border
            Rectangle()
                .fill(isFocused ? AppColorsV3.forestGreen : Color.gray.opacity(0.3))
                .frame(height: isFocused ? 2 : 1)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

#if DEBUG
struct NameStepView_Previews: PreviewProvider {
    static var previews: some View {
        NameStepView(
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
