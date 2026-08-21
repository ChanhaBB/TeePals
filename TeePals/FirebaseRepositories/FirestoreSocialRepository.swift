import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of SocialRepository.
/// Manages follow relationships with bidirectional writes for efficient queries.
final class FirestoreSocialRepository: SocialRepository {
    
    private let db = Firestore.firestore()
    
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
            .collection(FirestoreCollection.follows)
            .document(currentUid)
            .collection(FirestoreCollection.following)
            .document(targetUid)
        
        batch.setData([
            "createdAt": FieldValue.serverTimestamp()
        ], forDocument: followingRef)
        
        // Add to target user's followers list
        let followersRef = db
            .collection(FirestoreCollection.follows)
            .document(targetUid)
            .collection(FirestoreCollection.followers)
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
            .collection(FirestoreCollection.follows)
            .document(currentUid)
            .collection(FirestoreCollection.following)
            .document(targetUid)
        
        batch.deleteDocument(followingRef)
        
        // Remove from target user's followers list
        let followersRef = db
            .collection(FirestoreCollection.follows)
            .document(targetUid)
            .collection(FirestoreCollection.followers)
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
            .collection(FirestoreCollection.follows)
            .document(currentUid)
            .collection(FirestoreCollection.following)
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
            .collection(FirestoreCollection.follows)
            .document(currentUid)
            .collection(FirestoreCollection.followers)
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
            .collection(FirestoreCollection.follows)
            .document(currentUid)
            .collection(FirestoreCollection.following)
            .getDocuments()
        
        return snapshot.documents.map { $0.documentID }
    }
    
    // MARK: - Get Followers List
    
    func getFollowers() async throws -> [String] {
        guard let currentUid = currentUid else {
            throw SocialRepositoryError.notAuthenticated
        }
        
        let snapshot = try await db
            .collection(FirestoreCollection.follows)
            .document(currentUid)
            .collection(FirestoreCollection.followers)
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
    
    // MARK: - Get Counts for Any User
    
    func getFollowerCount(uid: String) async throws -> Int {
        let snapshot = try await db
            .collection(FirestoreCollection.follows)
            .document(uid)
            .collection(FirestoreCollection.followers)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    func getFollowingCount(uid: String) async throws -> Int {
        let snapshot = try await db
            .collection(FirestoreCollection.follows)
            .document(uid)
            .collection(FirestoreCollection.following)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    // MARK: - Enhanced Social Queries (Phase 4)
    
    func fetchMutualFollows(uid: String) async throws -> [FollowUser] {
        // Get following and followers for the user
        let followingSnapshot = try await db
            .collection(FirestoreCollection.follows)
            .document(uid)
            .collection(FirestoreCollection.following)
            .getDocuments()
        
        let followersSnapshot = try await db
            .collection(FirestoreCollection.follows)
            .document(uid)
            .collection(FirestoreCollection.followers)
            .getDocuments()
        
        let followingUids = Set(followingSnapshot.documents.map { $0.documentID })
        let followerUids = Set(followersSnapshot.documents.map { $0.documentID })
        
        // Mutual = intersection
        let mutualUids = followingUids.intersection(followerUids)
        
        // Fetch profiles for mutual follows
        var users: [FollowUser] = []
        for uid in mutualUids {
            let profileDoc = try? await db
                .collection(FirestoreCollection.profilesPublic)
                .document(uid)
                .getDocument()
            
            let nickname = profileDoc?.data()?["nickname"] as? String ?? "Unknown"
            let photoUrl = (profileDoc?.data()?["photoUrls"] as? [String])?.first
            
            users.append(FollowUser(
                uid: uid,
                nickname: nickname,
                photoUrl: photoUrl,
                isMutualFollow: true
            ))
        }
        
        return users.sorted { $0.nickname.lowercased() < $1.nickname.lowercased() }
    }
    
    func areMutualFollows(uid1: String, uid2: String) async throws -> Bool {
        // Check if uid1 follows uid2
        let followingDoc = try await db
            .collection(FirestoreCollection.follows)
            .document(uid1)
            .collection(FirestoreCollection.following)
            .document(uid2)
            .getDocument()
        
        guard followingDoc.exists else { return false }
        
        // Check if uid2 follows uid1
        let followerDoc = try await db
            .collection(FirestoreCollection.follows)
            .document(uid2)
            .collection(FirestoreCollection.following)
            .document(uid1)
            .getDocument()
        
        return followerDoc.exists
    }
    
    func fetchFollowersWithProfiles(uid: String) async throws -> [FollowUser] {
        // Parallel: fetch follower UIDs and following UIDs (for mutual detection)
        async let followersSnapshotTask = db
            .collection(FirestoreCollection.follows).document(uid)
            .collection(FirestoreCollection.followers).getDocuments()
        async let followingSnapshotTask = db
            .collection(FirestoreCollection.follows).document(uid)
            .collection(FirestoreCollection.following).getDocuments()

        let (followersSnapshot, followingSnapshot) = try await (followersSnapshotTask, followingSnapshotTask)
        let followerUids = followersSnapshot.documents.map { $0.documentID }
        let followingSet = Set(followingSnapshot.documents.map { $0.documentID })

        return try await fetchProfiles(for: followerUids, mutualSet: followingSet)
    }

    func fetchFollowingWithProfiles(uid: String) async throws -> [FollowUser] {
        // Parallel: fetch following UIDs and follower UIDs (for mutual detection)
        async let followingSnapshotTask = db
            .collection(FirestoreCollection.follows).document(uid)
            .collection(FirestoreCollection.following).getDocuments()
        async let followersSnapshotTask = db
            .collection(FirestoreCollection.follows).document(uid)
            .collection(FirestoreCollection.followers).getDocuments()

        let (followingSnapshot, followersSnapshot) = try await (followingSnapshotTask, followersSnapshotTask)
        let followingUids = followingSnapshot.documents.map { $0.documentID }
        let followersSet  = Set(followersSnapshot.documents.map { $0.documentID })

        return try await fetchProfiles(for: followingUids, mutualSet: followersSet)
    }

    /// Fetches public profiles for a list of UIDs concurrently and builds FollowUser entries.
    private func fetchProfiles(for uids: [String], mutualSet: Set<String>) async throws -> [FollowUser] {
        guard !uids.isEmpty else { return [] }

        let users: [FollowUser] = await withTaskGroup(of: FollowUser.self) { group in
            for uid in uids {
                group.addTask {
                    let doc = try? await self.db
                        .collection(FirestoreCollection.profilesPublic)
                        .document(uid)
                        .getDocument()
                    let nickname = doc?.data()?["nickname"] as? String ?? "Unknown"
                    let photoUrl = (doc?.data()?["photoUrls"] as? [String])?.first
                    return FollowUser(uid: uid, nickname: nickname, photoUrl: photoUrl,
                                     isMutualFollow: mutualSet.contains(uid))
                }
            }
            var results: [FollowUser] = []
            for await user in group { results.append(user) }
            return results
        }

        return users.sorted { lhs, rhs in
            if lhs.isMutualFollow != rhs.isMutualFollow { return lhs.isMutualFollow }
            return lhs.nickname.lowercased() < rhs.nickname.lowercased()
        }
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

