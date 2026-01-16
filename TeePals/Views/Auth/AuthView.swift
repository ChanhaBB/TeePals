import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Clean white background to match logo
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)
                
                Spacer()
                
                // Sign in section
                VStack(spacing: 24) {
                    if let error = authService.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    SignInWithAppleButton(.signIn) { request in
                        authService.handleSignInWithAppleRequest(request)
                    } onCompletion: { result in
                        authService.handleSignInWithAppleCompletion(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .cornerRadius(12)
                    
                    Text("We only use Apple Sign-In to protect your privacy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    let container = AppContainer()
    return AuthView()
        .environmentObject(container.authService)
}
