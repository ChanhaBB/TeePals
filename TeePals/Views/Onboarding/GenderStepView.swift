import SwiftUI

/// Step 4: Gender selection for Tier 1 onboarding.
struct GenderStepView: View {
    @ObservedObject var viewModel: Tier1OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "person.2.circle.fill")
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
            
            // Gender Options
            VStack(spacing: 12) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    GenderOptionButton(
                        gender: gender,
                        isSelected: viewModel.gender == gender,
                        action: { viewModel.gender = gender }
                    )
                }
            }
            .padding(.horizontal)
            
            // Privacy note
            HStack(spacing: 6) {
                Image(systemName: "eye.slash.fill")
                    .font(.caption)
                Text("Only shown when relevant to round preferences")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Gender Option Button

struct GenderOptionButton: View {
    let gender: Gender
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: iconName)
                    .font(.title2)
                    .frame(width: 32)
                
                // Label
                Text(gender.displayText)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.1, green: 0.45, blue: 0.25))
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(red: 0.1, green: 0.45, blue: 0.25).opacity(0.1) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(red: 0.1, green: 0.45, blue: 0.25) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
    
    private var iconName: String {
        switch gender {
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        case .nonbinary: return "figure.2"
        case .preferNot: return "hand.raised.fill"
        }
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

