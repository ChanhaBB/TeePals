import SwiftUI

struct CreateRoundView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.1, green: 0.45, blue: 0.25).opacity(0.5))
                    
                    Text("Create a Round")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Coming in Day 2")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationTitle("Create")
        }
    }
}

#Preview {
    CreateRoundView()
}

