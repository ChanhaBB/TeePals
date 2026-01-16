import SwiftUI

/// Modal view that appears when a user attempts a gated action without Tier 2 profile.
/// Shows missing requirements and routes to profile completion.
struct ProfileGateView: View {
    @ObservedObject var viewModel: ProfileGateViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    illustrationSection
                    missingRequirementsSection
                }
                .padding(24)
            }
            
            // Action buttons
            actionButtons
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Text("Complete Your Profile")
                .font(.headline)
            
            Spacer()
            
            Button {
                viewModel.dismissGate()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Illustration
    
    private var illustrationSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color(red: 0.1, green: 0.45, blue: 0.25))
            
            Text("Almost there!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete your profile to connect with other golfers, join rounds, and participate in the community.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Missing Requirements
    
    private var missingRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's missing")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            ForEach(viewModel.missingRequirements, id: \.self) { requirement in
                HStack(spacing: 12) {
                    Image(systemName: requirement.systemImage)
                        .font(.body)
                        .foregroundStyle(Color(red: 0.1, green: 0.45, blue: 0.25))
                        .frame(width: 24)
                    
                    Text(requirement.displayName)
                        .font(.body)
                    
                    Spacer()
                    
                    Image(systemName: "circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.startCompletion()
                dismiss()
            } label: {
                Text("Complete Profile")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.1, green: 0.45, blue: 0.25))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Button {
                viewModel.dismissGate()
                dismiss()
            } label: {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#if DEBUG
struct ProfileGateView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileGateView(
            viewModel: ProfileGateViewModel(
                profileRepository: MockProfileRepository(),
                currentUid: { "preview-uid" }
            )
        )
    }
}

private class MockProfileRepository: ProfileRepository {
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? { nil }
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? { nil }
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}
#endif

