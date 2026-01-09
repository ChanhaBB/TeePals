import Foundation

/// Repository protocol for social graph operations (follow/friend relationships).
/// Friends = mutual follow (both users follow each other).
protocol SocialRepository {
    
    /// Follow another user.
    /// - Parameter targetUid: The UID of the user to follow
    func follow(targetUid: String) async throws
    
    /// Unfollow another user.
    /// - Parameter targetUid: The UID of the user to unfollow
    func unfollow(targetUid: String) async throws
    
    /// Check if the current user is following a target user.
    /// - Parameter targetUid: The UID of the user to check
    /// - Returns: True if following
    func isFollowing(targetUid: String) async throws -> Bool
    
    /// Check if a target user is following the current user.
    /// - Parameter targetUid: The UID of the user to check
    /// - Returns: True if they are following the current user
    func isFollowedBy(targetUid: String) async throws -> Bool
    
    /// Check if two users are mutual follows (friends).
    /// - Parameter targetUid: The UID of the user to check
    /// - Returns: True if both users follow each other
    func isMutualFollow(targetUid: String) async throws -> Bool
    
    /// Get the list of UIDs the current user is following.
    /// - Returns: Array of user UIDs
    func getFollowing() async throws -> [String]
    
    /// Get the list of UIDs following the current user.
    /// - Returns: Array of user UIDs
    func getFollowers() async throws -> [String]
    
    /// Get the list of mutual follows (friends) for the current user.
    /// - Returns: Array of user UIDs who are mutual follows
    func getFriends() async throws -> [String]
}

