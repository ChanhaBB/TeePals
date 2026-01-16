import SwiftUI

/// View showing followers/following list with search and friends sorting.
struct FollowersListView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: AppContainer
    
    let uid: String
    let mode: ListMode
    
    @State private var users: [FollowUser] = []
    @State private var filteredUsers: [FollowUser] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedUserUid: String?
    
    enum ListMode {
        case followers
        case following
        
        var title: String {
            switch self {
            case .followers: return "Followers"
            case .following: return "Following"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGrouped
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if users.isEmpty {
                    emptyState
                } else {
                    usersList
                }
            }
            .searchable(text: $searchText, prompt: "Search by name")
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: Binding(
                get: { selectedUserUid.map { IdentifiableString(value: $0) } },
                set: { selectedUserUid = $0?.value }
            )) { wrapper in
                NavigationStack {
                    OtherUserProfileView(
                        viewModel: container.makeOtherUserProfileViewModel(uid: wrapper.value)
                    )
                }
            }
            .onChange(of: searchText) { _, newValue in
                filterUsers(query: newValue)
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: mode == .followers ? "person.2" : "person.badge.plus")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)
            
            Text(mode == .followers ? "No followers yet" : "Not following anyone yet")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Users List
    
    private var usersList: some View {
        List {
            // Friends section
            let friends = filteredUsers.filter { $0.isMutualFollow }
            if !friends.isEmpty {
                Section("Friends") {
                    ForEach(friends) { user in
                        userRow(user)
                    }
                }
            }
            
            // Others section
            let others = filteredUsers.filter { !$0.isMutualFollow }
            if !others.isEmpty {
                Section(friends.isEmpty ? "" : "Others") {
                    ForEach(others) { user in
                        userRow(user)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private func userRow(_ user: FollowUser) -> some View {
        Button {
            selectedUserUid = user.uid
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Avatar
                if let photoUrl = user.photoUrl, let url = URL(string: photoUrl) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialsView(user.nickname)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                } else {
                    initialsView(user.nickname)
                        .frame(width: 44, height: 44)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.nickname)
                        .font(AppTypography.labelLarge)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if user.isMutualFollow {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("Friend")
                                .font(AppTypography.caption)
                        }
                        .foregroundColor(AppColors.primary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
    
    private func initialsView(_ nickname: String) -> some View {
        Circle()
            .fill(AppColors.primary.opacity(0.15))
            .overlay(
                Text(String(nickname.prefix(1)))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.primary)
            )
    }
    
    // MARK: - Data Loading
    
    private func loadUsers() async {
        isLoading = true
        
        do {
            switch mode {
            case .followers:
                users = try await container.socialRepository.fetchFollowersWithProfiles(uid: uid)
            case .following:
                users = try await container.socialRepository.fetchFollowingWithProfiles(uid: uid)
            }
            filteredUsers = users
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func filterUsers(query: String) {
        if query.isEmpty {
            filteredUsers = users
        } else {
            filteredUsers = users.filter {
                $0.nickname.localizedCaseInsensitiveContains(query)
            }
        }
    }
}

// MARK: - Identifiable String Wrapper

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - Preview

#if DEBUG
struct FollowersListView_Previews: PreviewProvider {
    static var previews: some View {
        FollowersListView(uid: "user1", mode: .followers)
            .environmentObject(AppContainer())
    }
}
#endif

