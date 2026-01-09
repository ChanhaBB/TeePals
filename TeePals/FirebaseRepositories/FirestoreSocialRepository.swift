import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of SocialRepository.
/// Manages follow relationships with bidirectional writes for efficient queries.
final class FirestoreSocialRepository: SocialRepository {
    
    private let db = Firestore.firestore()
    
    private enum Collection {
        static let follows = "follows"
        static let following = "following"
        static let followers = "followers"
    }
    
    /// Returns the current authenticated user's UID, if available.
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Follow
    
    func follow(targetUid: String) async throws {
        guard let currentUid = currentUid else {
            throw SocialRepositoryError.notAuthenticated
        }
        
        guard currentUid != targetUid else {
            throw SocialRepositoryError.cannotFollowSelf
        }
        
        let batch = db.batch()
        
        // Add to current user's following list
        let followingRef = db
            .collection(Collection.follows)
            .document(currentUid)
            .collection(Collection.following)
            .document(targetUid)
        
        batch.setData([
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: followingRef)
        
        // Add to target user's followers list
        let followersRef = db
            .collection(Collection.follows)
            .document(targetUid)
            .collection(Collection.followers)
            .document(currentUid)
        
        batch.setData([
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: followersRef)
        
        try await batch.commit()
    }
    
    // MARK: - Unfollow
    
    func unfollow(targetUid: String) async throws {
        guard let currentUid = currentUid else {
            throw SocialRepositoryError.notAuthenticated
        }
        
        let batch = db.batch()
        
        // Remove from current user's following list
        let followingRef = db
            .collection(Collection.follows)
            .document(currentUid)
            .collection(Collection.following)
            .document(targetUid)
        
        batch.deleteDocument(followingRef)
        
        // Remove from target user's followers list
        let followersRef = db
            .collection(Collection.follows)
            .document(targetUid)
            .collection(Collection.followers)
            .document(currentUid)
        
        batch.deleteDocument(followersRef)
        
        try await batch.commit()
    }
    
    // MARK: - Check Following
    
    func isFollowing(targetUid: String) async throws -> Bool {
        guard let currentUid = currentUid else {
            throw SocialRepositoryError.notAuthenticated
        }
        
        let docRef = db
            .collection(Collection.follows)
            .document(currentUid)
            .collection(Collection.following)
            .document(targetUid)
        
        let snapshot = try await docRef.getDocument()
        return snapshot.exists
    }
    
    // MARK: - Check Followed By
    
    func isFollowedBy(targetUid: String) async throws -> Bool {
        guard let currentUid = currentUid else {
            throw SocialRepositoryError.notAuthenticated
        }
        
        let docRef = db
            .collection(Collection.follows)
            .document(currentUid)
            .collection(Collection.followers)
            .document(targetUid)
        
        let snapshot = try await docRef.getDocument()
        return snapshot.exists
    }
    
    // MARK: - Check Mutual Follow (Friends)
    
    func isMutualFollow(targetUid: String) async throws -> Bool {
        // Check both directions concurrently
        async let isFollowingTarget = isFollowing(targetUid: targetUid)
        async let isFollowedByTarget = isFollowedBy(targetUid: targetUid)
        
        let (following, followedBy) = try await (isFollowingTarget, isFollowedByTarget)
        return following && followedBy
    }
    
    // MARK: - Get Following List
    
    func getFollowing() async throws -> [String] {
        guard let currentUid = currentUid else {
            throw SocialRepositoryError.notAuthenticated
        }
        
        let snapshot = try await db
            .collection(Collection.follows)
            .document(currentUid)
            .collection(Collection.following)
            .getDocuments()
        
        return snapshot.documents.map { $0.documentID }
    }
    
    // MARK: - Get Followers List
    
    func getFollowers() async throws -> [String] {
        guard let currentUid = currentUid else {
            throw SocialRepositoryError.notAuthenticated
        }
        
        let snapshot = try await db
            .collection(Collection.follows)
            .document(currentUid)
            .collection(Collection.followers)
            .getDocuments()
        
        return snapshot.documents.map { $0.documentID }
    }
    
    // MARK: - Get Friends (Mutual Follows)
    
    func getFriends() async throws -> [String] {
        // Get both lists concurrently
        async let followingList = getFollowing()
        async let followersList = getFollowers()
        
        let (following, followers) = try await (followingList, followersList)
        
        // Friends = intersection of following and followers
        let followingSet = Set(following)
        let followersSet = Set(followers)
        
        return Array(followingSet.intersection(followersSet))
    }
}

// MARK: - Repository Errors

enum SocialRepositoryError: LocalizedError {
    case notAuthenticated
    case cannotFollowSelf
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .cannotFollowSelf:
            return "You cannot follow yourself."
        }
    }
}

