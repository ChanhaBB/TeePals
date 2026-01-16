import Foundation
import FirebaseAuth
import FirebaseStorage
import UIKit

/// Protocol for storage operations.
/// Views depend on this protocol, not Firebase directly.
protocol StorageServiceProtocol {
    /// Uploads a profile photo and returns the download URL.
    /// - Parameter imageData: The JPEG image data to upload
    /// - Returns: The download URL string
    func uploadProfilePhoto(_ imageData: Data) async throws -> String
    
    /// Deletes a profile photo by URL.
    /// - Parameter url: The download URL of the photo to delete
    func deleteProfilePhoto(url: String) async throws
    
    /// Uploads a post photo and returns the download URL.
    /// - Parameters:
    ///   - imageData: The JPEG image data to upload
    ///   - postId: Optional post ID (for organization)
    /// - Returns: The download URL string
    func uploadPostPhoto(_ imageData: Data, postId: String?) async throws -> String
    
    /// Deletes a post photo by URL.
    /// - Parameter url: The download URL of the photo to delete
    func deletePostPhoto(url: String) async throws

    /// Uploads a chat photo and returns the download URL.
    /// - Parameters:
    ///   - imageData: The JPEG image data to upload
    ///   - roundId: The round ID for organization
    ///   - messageId: Optional message ID (use "temp" if nil)
    /// - Returns: The download URL string
    func uploadChatPhoto(_ imageData: Data, roundId: String, messageId: String?) async throws -> String
}

/// Firebase Storage implementation for profile photo uploads.
/// Path: profilePhotos/{uid}/{uuid}.jpg
final class StorageService: StorageServiceProtocol {
    
    private let storage = Storage.storage()
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Upload Profile Photo
    
    func uploadProfilePhoto(_ imageData: Data) async throws -> String {
        guard let uid = currentUid else {
            throw StorageError.notAuthenticated
        }
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let path = "profilePhotos/\(uid)/\(filename)"
        let ref = storage.reference().child(path)
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }
    
    // MARK: - Delete Profile Photo
    
    func deleteProfilePhoto(url: String) async throws {
        guard currentUid != nil else {
            throw StorageError.notAuthenticated
        }
        
        // Extract path from URL and delete
        let ref = storage.reference(forURL: url)
        try await ref.delete()
    }
    
    // MARK: - Upload Post Photo
    
    func uploadPostPhoto(_ imageData: Data, postId: String?) async throws -> String {
        guard let uid = currentUid else {
            throw StorageError.notAuthenticated
        }
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let folder = postId ?? "temp"
        let path = "postPhotos/\(uid)/\(folder)/\(filename)"
        let ref = storage.reference().child(path)
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload
        _ = try await ref.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }
    
    // MARK: - Delete Post Photo

    func deletePostPhoto(url: String) async throws {
        guard currentUid != nil else {
            throw StorageError.notAuthenticated
        }

        let ref = storage.reference(forURL: url)
        try await ref.delete()
    }

    // MARK: - Upload Chat Photo

    func uploadChatPhoto(_ imageData: Data, roundId: String, messageId: String?) async throws -> String {
        guard currentUid != nil else {
            throw StorageError.notAuthenticated
        }

        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let folder = messageId ?? "temp"
        let path = "chatPhotos/\(roundId)/\(folder)/\(filename)"
        let ref = storage.reference().child(path)

        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // Upload
        _ = try await ref.putDataAsync(imageData, metadata: metadata)

        // Get download URL
        let downloadURL = try await ref.downloadURL()
        return downloadURL.absoluteString
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case notAuthenticated
    case uploadFailed
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to upload photos."
        case .uploadFailed:
            return "Failed to upload photo. Please try again."
        case .invalidImage:
            return "Invalid image format."
        }
    }
}

// MARK: - Image Compression Helper

extension UIImage {
    /// Compresses image to JPEG data with max dimension and quality.
    /// - Parameters:
    ///   - maxDimension: Maximum width/height (default 1024)
    ///   - quality: JPEG compression quality 0-1 (default 0.8)
    /// - Returns: Compressed JPEG data
    func compressedJPEGData(maxDimension: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        // Guard against invalid dimensions
        guard size.width > 0, size.height > 0 else {
            return jpegData(compressionQuality: quality)
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized?.jpegData(compressionQuality: quality)
    }
}

