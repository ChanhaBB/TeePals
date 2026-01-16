import Foundation
import FirebaseFirestore

/// Firestore implementation of UserRepository.
/// Handles operations on the users/{uid} collection for basic user metadata.
final class FirestoreUserRepository: UserRepository {

    private let db = Firestore.firestore()

    // MARK: - User Existence Check

    func userExists(uid: String) async throws -> Bool {
        let docRef = db.collection(FirestoreCollection.users).document(uid)
        let snapshot = try await docRef.getDocument()
        return snapshot.exists
    }

    // MARK: - Create User

    func createUserIfNeeded(uid: String, displayName: String) async throws {
        let docRef = db.collection(FirestoreCollection.users).document(uid)

        // Check if document already exists
        let snapshot = try await docRef.getDocument()

        if !snapshot.exists {
            // Create new user document with server timestamps
            let data: [String: Any] = [
                "displayName": displayName,
                "createdAt": FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ]
            try await docRef.setData(data)
        } else {
            // User already exists, update last active timestamp
            try await updateLastActive(uid: uid)
        }
    }

    // MARK: - Update Last Active

    func updateLastActive(uid: String) async throws {
        let docRef = db.collection(FirestoreCollection.users).document(uid)
        try await docRef.updateData([
            "lastActiveAt": FieldValue.serverTimestamp()
        ])
    }
}
