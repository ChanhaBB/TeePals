import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject private var authService: AuthService
    
    @State private var showingSignOutAlert = false
    @State private var showingEditProfile = false
    
    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && viewModel.publicProfile == nil {
                        loadingState
                    } else if let profile = viewModel.publicProfile {
                        profileContent(profile: profile)
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingSignOutAlert = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadProfile()
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Error", isPresented: showingError) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showingEditProfile) {
                editProfileSheet
            }
        }
    }
    
    // MARK: - Profile Content
    
    private func profileContent(profile: PublicProfile) -> some View {
        VStack(spacing: 20) {
            // Profile Card
            PublicProfileCardView(profile: profile, style: .full)
            
            // Social Stats
            socialStatsCard
            
            // Actions
            actionsSection
        }
    }
    
    // MARK: - Social Stats Card
    
    private var socialStatsCard: some View {
        HStack(spacing: 0) {
            statItem(count: viewModel.followingCount, label: "Following")
            
            Divider()
                .frame(height: 40)
            
            statItem(count: viewModel.followerCount, label: "Followers")
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showingEditProfile = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Profile")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
            
            Button(role: .destructive) {
                showingSignOutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemBackground))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading profile...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Profile Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Set up your profile to connect with other golfers.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingEditProfile = true
            } label: {
                Text("Set Up Profile")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Edit Profile Sheet
    
    private var editProfileSheet: some View {
        // Placeholder - will connect to ProfileSetupView with edit mode
        NavigationStack {
            Text("Edit Profile")
                .navigationTitle("Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingEditProfile = false
                        }
                    }
                }
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

#Preview {
    ProfileView(
        viewModel: ProfileViewModel(
            profileRepository: MockProfileRepository(),
            socialRepository: MockSocialRepository(),
            currentUid: { "preview-uid" }
        )
    )
    .environmentObject(AuthService())
}

// MARK: - Mock Repositories for Preview

private class MockProfileRepository: ProfileRepository {
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? {
        return .preview
    }
    
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? {
        return nil
    }
    
    func upsertPublicProfile(_ profile: PublicProfile) async throws {}
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {}
}

private class MockSocialRepository: SocialRepository {
    func follow(targetUid: String) async throws {}
    func unfollow(targetUid: String) async throws {}
    func isFollowing(targetUid: String) async throws -> Bool { false }
    func isFollowedBy(targetUid: String) async throws -> Bool { false }
    func isMutualFollow(targetUid: String) async throws -> Bool { false }
    func getFollowing() async throws -> [String] { ["1", "2", "3"] }
    func getFollowers() async throws -> [String] { ["1", "2"] }
    func getFriends() async throws -> [String] { ["1"] }
}
