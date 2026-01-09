import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            // Clean white background
            Color.white
                .ignoresSafeArea()
            
            // Logo slightly above center for visual balance
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .offset(y: -40)
        }
    }
}

#Preview {
    LaunchScreenView()
}
