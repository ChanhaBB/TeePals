import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of ProfileRepository.
/// Handles the split between public and private profile collections.
/// Manually handles GeoPoint <-> GeoLocation conversion.
final class FirestoreProfileRepository: ProfileRepository {
    
    private let db = Firestore.firestore()
    
    /// Returns the current authenticated user's UID, if available.
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Profile Existence Check

    func profileExists(uid: String) async throws -> Bool {
        let docRef = db.collection(FirestoreCollection.profilesPublic).document(uid)
        let snapshot = try await docRef.getDocument()
        return snapshot.exists
    }

    // MARK: - Fetch Public Profile
    
    func fetchPublicProfile(uid: String) async throws -> PublicProfile? {
        let docRef = db.collection(FirestoreCollection.profilesPublic).document(uid)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        
        return try decodePublicProfile(from: data, id: snapshot.documentID)
    }
    
    // MARK: - Fetch Private Profile
    
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile? {
        // Only allow fetching own private profile
        guard let currentUid = currentUid, currentUid == uid else {
            throw ProfileRepositoryError.permissionDenied
        }
        
        let docRef = db.collection(FirestoreCollection.profilesPrivate).document(uid)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        
        return try decodePrivateProfile(from: data, id: snapshot.documentID)
    }
    
    // MARK: - Upsert Public Profile
    
    func upsertPublicProfile(_ profile: PublicProfile) async throws {
        guard let uid = currentUid else {
            throw ProfileRepositoryError.notAuthenticated
        }
        
        let docRef = db.collection(FirestoreCollection.profilesPublic).document(uid)
        
        // Build data dictionary to use server timestamp and GeoPoint
        var data: [String: Any] = [
            "nickname": profile.nickname,
            "primaryCityLabel": profile.primaryCityLabel,
            "primaryLocation": GeoPoint(
                latitude: profile.primaryLocation.latitude,
                longitude: profile.primaryLocation.longitude
            ),
            "photoUrls": profile.photoUrls,  // Always write array (even if empty)
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Optional fields - set value or delete if nil
        // Using FieldValue.delete() ensures cleared fields are actually removed
        data["gender"] = profile.gender?.rawValue ?? FieldValue.delete()
        data["occupation"] = profile.occupation ?? FieldValue.delete()
        data["bio"] = profile.bio ?? FieldValue.delete()
        data["avgScore"] = profile.avgScore ?? FieldValue.delete()
        data["experienceLevel"] = profile.experienceLevel?.rawValue ?? FieldValue.delete()
        data["playsPerMonth"] = profile.playsPerMonth ?? FieldValue.delete()
        data["skillLevel"] = profile.skillLevel?.rawValue ?? FieldValue.delete()
        data["birthYear"] = profile.birthYear ?? FieldValue.delete()
        data["ageDecade"] = profile.ageDecade?.rawValue ?? FieldValue.delete()  // Deprecated but keep for backward compat
        data["instagramUsername"] = profile.instagramUsername ?? FieldValue.delete()
        
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
        
        let docRef = db.collection(FirestoreCollection.profilesPrivate).document(uid)
        
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
    
    // MARK: - Manual Decoding
    
    private func decodePublicProfile(from data: [String: Any], id: String) throws -> PublicProfile {
        guard let nickname = data["nickname"] as? String,
              let primaryCityLabel = data["primaryCityLabel"] as? String,
              let geoPoint = data["primaryLocation"] as? GeoPoint else {
            throw ProfileRepositoryError.decodingFailed
        }
        
        let primaryLocation = GeoLocation(
            latitude: geoPoint.latitude,
            longitude: geoPoint.longitude
        )
        
        // Parse timestamps
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // Parse photo URLs array (default to empty)
        let photoUrls = data["photoUrls"] as? [String] ?? []
        
        // Parse optional enums
        var gender: Gender?
        if let genderRaw = data["gender"] as? String {
            gender = Gender(rawValue: genderRaw)
        }
        
        var skillLevel: SkillLevel?
        if let skillRaw = data["skillLevel"] as? String {
            skillLevel = SkillLevel(rawValue: skillRaw)
        }
        
        var ageDecade: AgeDecade?
        if let ageRaw = data["ageDecade"] as? String {
            ageDecade = AgeDecade(rawValue: ageRaw)
        }
        
        var experienceLevel: ExperienceLevel?
        if let expRaw = data["experienceLevel"] as? String {
            experienceLevel = ExperienceLevel(rawValue: expRaw)
        }
        
        // Parse birthYear (new field for exact age calculation)
        let birthYear = data["birthYear"] as? Int

        return PublicProfile(
            id: id,
            nickname: nickname,
            photoUrls: photoUrls,
            gender: gender,
            occupation: data["occupation"] as? String,
            bio: data["bio"] as? String,
            primaryCityLabel: primaryCityLabel,
            primaryLocation: primaryLocation,
            avgScore: data["avgScore"] as? Int,
            experienceLevel: experienceLevel,
            playsPerMonth: data["playsPerMonth"] as? Int,
            skillLevel: skillLevel,
            birthYear: birthYear,
            ageDecade: ageDecade,
            instagramUsername: data["instagramUsername"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func decodePrivateProfile(from data: [String: Any], id: String) throws -> PrivateProfile {
        guard let birthDate = data["birthDate"] as? String else {
            throw ProfileRepositoryError.decodingFailed
        }
        
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return PrivateProfile(
            id: id,
            birthDate: birthDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Repository Errors

enum ProfileRepositoryError: LocalizedError, Equatable {
    case notAuthenticated
    case permissionDenied
    case notFound
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .permissionDenied:
            return "You don't have permission to access this profile."
        case .notFound:
            return "Profile not found."
        case .decodingFailed:
            return "Failed to read profile data."
        }
    }
}
