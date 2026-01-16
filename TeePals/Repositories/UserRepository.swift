import Foundation

/// Repository protocol for user data access.
/// Handles operations on the users/{uid} collection which stores basic user metadata.
/// This is separate from ProfileRepository which handles profiles_public and profiles_private.
protocol UserRepository {

    /// Checks if a user document exists in the users collection.
    /// - Parameter uid: The user's unique identifier
    /// - Returns: True if the user document exists, false otherwise
    func userExists(uid: String) async throws -> Bool

    /// Creates a new user document if it doesn't already exist.
    /// - Parameters:
    ///   - uid: The user's unique identifier
    ///   - displayName: The user's display name from Apple Sign In
    /// - Throws: Repository errors (network, permission, etc.)
    func createUserIfNeeded(uid: String, displayName: String) async throws

    /// Updates the user's last active timestamp.
    /// Called after successful authentication to track activity.
    /// - Parameter uid: The user's unique identifier
    /// - Throws: Repository errors (network, permission, etc.)
    func updateLastActive(uid: String) async throws
}
