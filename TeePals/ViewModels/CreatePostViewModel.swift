import Foundation
import SwiftUI
import PhotosUI

/// ViewModel for creating a new post.
/// Handles text input, photo selection, round linking, and submission.
@MainActor
final class CreatePostViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let postsRepository: PostsRepository
    private let roundsRepository: RoundsRepository
    private let storageService: StorageServiceProtocol
    private let currentUid: () -> String?
    
    // MARK: - State
    
    @Published var text: String = ""
    @Published var selectedPhotos: [PhotosPickerItem] = []
    @Published var photoImages: [UIImage] = []
    @Published var photoUrls: [String] = []
    @Published var visibility: PostVisibility = .public
    @Published var linkedRound: Round?
    
    @Published var isLoading = false
    @Published var isUploadingPhotos = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var isShowingRoundPicker = false
    
    // Recent rounds for linking
    @Published var recentRounds: [Round] = []
    @Published var isLoadingRounds = false
    
    // MARK: - Constants
    
    let maxPhotos = Post.maxPhotos
    let maxTextLength = Post.maxTextLength
    
    // MARK: - Init
    
    init(
        postsRepository: PostsRepository,
        roundsRepository: RoundsRepository,
        storageService: StorageServiceProtocol,
        currentUid: @escaping () -> String?
    ) {
        self.postsRepository = postsRepository
        self.roundsRepository = roundsRepository
        self.storageService = storageService
        self.currentUid = currentUid
    }
    
    // MARK: - Computed
    
    var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        text.count <= maxTextLength &&
        !isLoading
    }
    
    var remainingPhotos: Int {
        maxPhotos - photoImages.count
    }
    
    var characterCount: Int {
        text.count
    }
    
    var uid: String? { currentUid() }
    
    // MARK: - Photo Handling
    
    func loadPhotos() async {
        guard !selectedPhotos.isEmpty else { return }
        
        var newImages: [UIImage] = []
        
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(image)
            }
        }
        
        // Limit to max photos
        let available = maxPhotos - photoImages.count
        photoImages.append(contentsOf: newImages.prefix(available))
        selectedPhotos = []
    }
    
    func removePhoto(at index: Int) {
        guard index < photoImages.count else { return }
        photoImages.remove(at: index)
    }
    
    private func uploadPhotos() async throws -> [String] {
        guard !photoImages.isEmpty else { return [] }
        
        isUploadingPhotos = true
        var urls: [String] = []
        let total = photoImages.count
        
        for (index, image) in photoImages.enumerated() {
            guard let data = image.compressedJPEGData(maxDimension: 1080, quality: 0.8) else {
                continue
            }
            
            let url = try await storageService.uploadPostPhoto(data, postId: nil)
            urls.append(url)
            uploadProgress = Double(index + 1) / Double(total)
        }
        
        isUploadingPhotos = false
        uploadProgress = 0
        return urls
    }
    
    // MARK: - Round Linking
    
    func loadRecentRounds() async {
        guard let uid = currentUid() else { return }

        isLoadingRounds = true

        do {
            // Fetch user's own rounds from past 7 days to next 30 days
            // Users can link rounds they've hosted (of any visibility)
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

            let filters = RoundFilters(
                status: nil,  // Include all statuses (will filter client-side)
                dateRange: .custom(start: startDate, end: endDate),
                hostUid: uid  // Only fetch user's own rounds
            )

            var rounds = try await roundsRepository.fetchRounds(
                filters: filters,
                limit: 50,
                lastRound: nil
            )

            // Filter out canceled rounds only
            rounds = rounds.filter { $0.status != .canceled }

            // Sort by date proximity (soonest first)
            let now = Date()
            rounds.sort { (round1, round2) -> Bool in
                guard let date1 = round1.displayTeeTime,
                      let date2 = round2.displayTeeTime else {
                    return false
                }

                let diff1 = abs(date1.timeIntervalSince(now))
                let diff2 = abs(date2.timeIntervalSince(now))
                return diff1 < diff2
            }

            recentRounds = Array(rounds.prefix(20))
        } catch {
            print("Failed to load recent rounds: \(error)")
        }

        isLoadingRounds = false
    }
    
    func selectRound(_ round: Round) {
        linkedRound = round
        isShowingRoundPicker = false
    }
    
    func removeLinkedRound() {
        linkedRound = nil
    }
    
    // MARK: - Create Post
    
    func createPost() async -> Post? {
        guard canPost, let uid = currentUid() else { return nil }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Upload photos first
            let uploadedUrls = try await uploadPhotos()
            
            // Create post
            let post = Post(
                authorUid: uid,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                photoUrls: uploadedUrls,
                linkedRoundId: linkedRound?.id,
                visibility: visibility
            )
            
            let createdPost = try await postsRepository.createPost(post)
            
            isLoading = false
            return createdPost
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        text = ""
        selectedPhotos = []
        photoImages = []
        photoUrls = []
        visibility = .public
        linkedRound = nil
        errorMessage = nil
    }
}





