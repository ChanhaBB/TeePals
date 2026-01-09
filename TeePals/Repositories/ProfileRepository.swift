import Foundation

/// Repository protocol for profile data access.
/// Implementations handle the actual data source (Firestore, mock, etc.)
/// Views and ViewModels depend only on this protocol, not on Firebase directly.
protocol ProfileRepository {
    
    /// Fetches a user's public profile by UID.
    /// - Parameter uid: The user's unique identifier
    /// - Returns: The public profile if it exists
    /// - Throws: Repository errors (not found, network, etc.)
    func fetchPublicProfile(uid: String) async throws -> PublicProfile?
    
    /// Fetches a user's private profile by UID.
    /// Only the profile owner should be able to access this.
    /// - Parameter uid: The user's unique identifier
    /// - Returns: The private profile if it exists
    /// - Throws: Repository errors (not found, permission denied, etc.)
    func fetchPrivateProfile(uid: String) async throws -> PrivateProfile?
    
    /// Creates or updates a public profile.
    /// - Parameter profile: The public profile to upsert
    /// - Throws: Repository errors (validation, network, etc.)
    func upsertPublicProfile(_ profile: PublicProfile) async throws
    
    /// Creates or updates a private profile.
    /// Only the profile owner should be able to modify this.
    /// - Parameter profile: The private profile to upsert
    /// - Throws: Repository errors (permission denied, network, etc.)
    func upsertPrivateProfile(_ profile: PrivateProfile) async throws
}

