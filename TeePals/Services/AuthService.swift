import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFunctions

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

    // MARK: - Dependencies

    private let profileRepository: ProfileRepository
    private let userRepository: UserRepository

    init(profileRepository: ProfileRepository, userRepository: UserRepository) {
        self.profileRepository = profileRepository
        self.userRepository = userRepository
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
            // v2: Check profiles_public/{uid} as source of truth
            let exists = try await profileRepository.profileExists(uid: userId)
            if exists {
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
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain,
               let code = ASAuthorizationError.Code(rawValue: nsError.code),
               code == .canceled || code == .unknown {
                return
            }
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
        do {
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

            // Create user document if needed, or update last active if exists
            try await userRepository.createUserIfNeeded(uid: user.uid, displayName: displayName)
        } catch {
            print("Error creating/updating user: \(error)")
        }
    }
    
    // MARK: - Account Deletion

    @Published var isDeletingAccount = false

    func deleteAccount() async {
        guard Auth.auth().currentUser != nil else {
            errorMessage = "You must be signed in to delete your account."
            return
        }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await reauthenticateWithApple()

            let callable = Functions.functions().httpsCallable("deleteUserAccount")
            _ = try await callable.call()

            try Auth.auth().signOut()
            authState = .unauthenticated
        } catch let error as NSError where
            error.domain == ASAuthorizationError.errorDomain &&
            (ASAuthorizationError.Code(rawValue: error.code) == .canceled ||
             ASAuthorizationError.Code(rawValue: error.code) == .unknown) {
            // User canceled the re-auth prompt — not an error
            return
        } catch {
            print("Account deletion error: \(error)")
            errorMessage = "Failed to delete account. Please try again."
        }
    }

    private func reauthenticateWithApple() async throws {
        let nonce = randomNonceString()
        let hashedNonce = sha256(nonce)

        let credential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let delegate = AppleSignInDelegate(continuation: continuation)
            self.reAuthDelegate = delegate

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.performRequests()
        }

        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AccountDeletionError.missingToken
        }

        let oauthCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        try await Auth.auth().currentUser?.reauthenticate(with: oauthCredential)
    }

    private var reAuthDelegate: AppleSignInDelegate?

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
            print("⚠️ SecRandomCopyBytes failed (OSStatus \(errorCode)) — falling back to UUID nonce")
            return UUID().uuidString
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

// MARK: - Account Deletion Helpers

enum AccountDeletionError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Unable to process Apple credential for re-authentication."
        }
    }
}

/// Wraps ASAuthorizationControllerDelegate in a continuation for async/await usage.
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: AccountDeletionError.missingToken)
        }
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

