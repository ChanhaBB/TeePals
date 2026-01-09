import SwiftUI

struct RoundsView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.1, green: 0.45, blue: 0.25).opacity(0.5))
                    
                    Text("No rounds nearby")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Create a round or check back later")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("Rounds")
        }
    }
}

#Preview {
    RoundsView()
}

