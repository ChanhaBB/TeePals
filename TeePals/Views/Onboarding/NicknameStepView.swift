import SwiftUI

/// Step 1: Nickname entry for Tier 1 onboarding.
struct NicknameStepView: View {
    @ObservedObject var viewModel: Tier1OnboardingViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color(red: 0.1, green: 0.45, blue: 0.25))
            
            // Title & Subtitle
            VStack(spacing: 8) {
                Text(viewModel.currentStep.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(viewModel.currentStep.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Input Field
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: AppSpacing.sm) {
                    TextField("Enter name", text: $viewModel.nickname)
                        .font(.title3)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .focused($isFocused)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                    
                    // Keyboard dismiss button
                    if isFocused {
                        Button {
                            isFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isFocused)
                
                // Validation hint
                HStack {
                    if !viewModel.nickname.isEmpty {
                        if viewModel.isNicknameValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Looks good!")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("2-20 characters required")
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("2-20 characters")
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(viewModel.trimmedNickname.count)/20")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal)
            
            Spacer()
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = false
        }
    }
}

#if DEBUG
struct NicknameStepView_Previews: PreviewProvider {
    static var previews: some View {
        NicknameStepView(
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

