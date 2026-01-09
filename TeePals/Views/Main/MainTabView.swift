import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RoundsView()
                .tabItem {
                    Label("Rounds", systemImage: "list.bullet.circle.fill")
                }
                .tag(0)
            
            CreateRoundView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(2)
        }
        .tint(Color(red: 0.1, green: 0.45, blue: 0.25))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}

