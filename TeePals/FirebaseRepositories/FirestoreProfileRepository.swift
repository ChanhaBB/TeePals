import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of ProfileRepository.
/// Handles the split between public and private profile collections.
final class FirestoreProfileRepository: ProfileRepository {
    
    private let db = Firestore.firestore()
    
    private enum Collection {
        static let publicProfiles = "profiles_public"
        static let privateProfiles = "profiles_private"
    }
    
    /// Returns the current authenticated user's UID, if available.
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Fetch Public Profile
    
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? {
        let docRef = db.collection(Collection.publicProfiles).document(uid)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists else {
            return nil
        }
        
        var profile = try snapshot.data(as: PublicProfile.self)
        profile.id = snapshot.documentID
        return profile
    }
    
    // MARK: - Fetch Private Profile
    
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? {
        // Only allow fetching own private profile
        guard let currentUid = currentUid, currentUid == uid else {
            throw ProfileRepositoryError.permissionDenied
        }
        
        let docRef = db.collection(Collection.privateProfiles).document(uid)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists else {
            return nil
        }
        
        var profile = try snapshot.data(as: PrivateProfile.self)
        profile.id = snapshot.documentID
        return profile
    }
    
    // MARK: - Upsert Public Profile
    
    func upsertPublicProfile(_ profile: PublicProfile) async throws {
        guard let uid = currentUid else {
            throw ProfileRepositoryError.notAuthenticated
        }
        
        let docRef = db.collection(Collection.publicProfiles).document(uid)
        
        // Build data dictionary to use server timestamp
        var data: [String: Any] = [
            "nickname": profile.nickname,
            "primaryCityLabel": profile.primaryCityLabel,
            "primaryLocation": GeoPoint(
                latitude: profile.primaryLocation.latitude,
                longitude: profile.primaryLocation.longitude
            ),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Optional fields - only include if present
        if let photoUrl = profile.photoUrl {
            data["photoUrl"] = photoUrl
        }
        if let gender = profile.gender {
            data["gender"] = gender.rawValue
        }
        if let occupation = profile.occupation {
            data["occupation"] = occupation
        }
        if let bio = profile.bio {
            data["bio"] = bio
        }
        if let avgScore18 = profile.avgScore18 {
            data["avgScore18"] = avgScore18
        }
        if let experienceYears = profile.experienceYears {
            data["experienceYears"] = experienceYears
        }
        if let playsPerMonth = profile.playsPerMonth {
            data["playsPerMonth"] = playsPerMonth
        }
        if let skillLevel = profile.skillLevel {
            data["skillLevel"] = skillLevel.rawValue
        }
        if let ageDecade = profile.ageDecade {
            data["ageDecade"] = ageDecade.rawValue
        }
        
        // Check if document exists to set createdAt only on create
        let snapshot = try await docRef.getDocument()
        if !snapshot.exists {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        
        try await docRef.setData(data, merge: true)
    }
    
    // MARK: - Upsert Private Profile
    
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws {
        guard let uid = currentUid else {
            throw ProfileRepositoryError.notAuthenticated
        }
        
        let docRef = db.collection(Collection.privateProfiles).document(uid)
        
        // Build data dictionary to use server timestamp
        // Private profile only contains birthDate - no public fields leak here
        var data: [String: Any] = [
            "birthDate": profile.birthDate,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Check if document exists to set createdAt only on create
        let snapshot = try await docRef.getDocument()
        if !snapshot.exists {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        
        try await docRef.setData(data, merge: true)
    }
}

// MARK: - Repository Errors

enum ProfileRepositoryError: LocalizedError {
    case notAuthenticated
    case permissionDenied
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .permissionDenied:
            return "You don't have permission to access this profile."
        case .notFound:
            return "Profile not found."
        }
    }
}

