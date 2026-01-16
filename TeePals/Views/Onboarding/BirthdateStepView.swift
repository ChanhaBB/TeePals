import SwiftUI

/// Step 2: Birthdate entry for Tier 1 onboarding.
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
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "calendar.circle.fill")
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
            
            // Date Picker
            VStack(spacing: 16) {
                DatePicker(
                    "Birth Date",
                    selection: birthDateBinding,
                    in: minDate...maxDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                // Age display
                if let age = calculatedAge {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("You're \(age) years old")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)
            
            // Privacy note
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("Your birth date is private and never shown to others")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.birthDate ?? defaultDate },
            set: { viewModel.birthDate = $0 }
        )
    }
    
    private var calculatedAge: Int? {
        guard let birthDate = viewModel.birthDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year
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

