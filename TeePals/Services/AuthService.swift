import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

enum AuthState: Equatable {
    case loading
    case unauthenticated
    case needsProfile
    case authenticated
}

@MainActor
class AuthService: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentUser: FirebaseAuth.User?
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let db = Firestore.firestore()
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentUser = user
                
                if let user = user {
                    await self.checkProfileStatus(userId: user.uid)
                } else {
                    self.authState = .unauthenticated
                }
            }
        }
    }
    
    private func checkProfileStatus(userId: String) async {
        do {
            let doc = try await db.collection(FirestoreCollection.profiles).document(userId).getDocument()
            if doc.exists {
                authState = .authenticated
            } else {
                authState = .needsProfile
            }
        } catch {
            // If we can't check profile, assume needs profile setup
            authState = .needsProfile
        }
    }
    
    // MARK: - Apple Sign In
    
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                await signInWithApple(authorization: authorization)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func signInWithApple(authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to process Apple Sign In"
            return
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        do {
            let result = try await Auth.auth().signIn(with: credential)
            await createUserIfNeeded(user: result.user, fullName: appleIDCredential.fullName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func createUserIfNeeded(user: FirebaseAuth.User, fullName: PersonNameComponents?) async {
        let userRef = db.collection(FirestoreCollection.users).document(user.uid)
        
        do {
            let doc = try await userRef.getDocument()
            if !doc.exists {
                // Build display name from Apple's full name or fall back to email
                var displayName = "Golfer"
                if let givenName = fullName?.givenName {
                    displayName = givenName
                    if let familyName = fullName?.familyName {
                        displayName += " \(familyName)"
                    }
                } else if let email = user.email {
                    displayName = email.components(separatedBy: "@").first ?? "Golfer"
                }
                
                let newUser = User(displayName: displayName)
                try userRef.setData(from: newUser)
            } else {
                // Update last active
                try await userRef.updateData(["lastActiveAt": FieldValue.serverTimestamp()])
            }
        } catch {
            print("Error creating/updating user: \(error)")
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            authState = .unauthenticated
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Profile Completion
    
    func completeProfileSetup() {
        authState = .authenticated
    }
    
    // MARK: - Nonce Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

