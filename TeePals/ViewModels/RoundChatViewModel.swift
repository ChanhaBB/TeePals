import Foundation
import Combine
import SwiftUI
import PhotosUI

/// ViewModel for round group chat.
/// Handles real-time message subscription, sending, and state management.
@MainActor
final class RoundChatViewModel: ObservableObject {
    
    // MARK: - Dependencies

    private let chatRepository: ChatRepository
    private let roundsRepository: RoundsRepository
    private let profileRepository: ProfileRepository
    private let storageService: StorageServiceProtocol
    private let currentUid: () -> String?
    
    // MARK: - State
    
    let roundId: String
    @Published var round: Round?
    @Published var messages: [ChatMessage] = []
    @Published var senderProfiles: [String: PublicProfile] = [:]  // uid -> profile
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var canSendMessages = false
    
    // Composer state
    @Published var composerText = ""
    @Published var isSending = false

    // Photo picker state
    @Published var selectedPhoto: PhotosPickerItem?
    @Published var photoImage: UIImage?
    @Published var isUploadingPhoto = false
    @Published var uploadProgress: Double = 0

    // Pagination
    private var oldestMessageCursor: ChatPageCursor?
    private var hasMoreMessages = true
    
    // Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Pending messages (optimistic)
    private var pendingMessages: [String: ChatMessage] = [:] // clientNonce -> message
    
    // MARK: - Init
    
    init(
        roundId: String,
        chatRepository: ChatRepository,
        roundsRepository: RoundsRepository,
        profileRepository: ProfileRepository,
        storageService: StorageServiceProtocol,
        currentUid: @escaping () -> String?
    ) {
        self.roundId = roundId
        self.chatRepository = chatRepository
        self.roundsRepository = roundsRepository
        self.profileRepository = profileRepository
        self.storageService = storageService
        self.currentUid = currentUid
    }
    
    // MARK: - Computed Properties

    var isComposerEnabled: Bool {
        canSendMessages && !isSending && (hasTextInput || hasPhotoSelected)
    }

    private var hasTextInput: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasPhotoSelected: Bool {
        photoImage != nil
    }

    var uid: String? { currentUid() }
    
    func loadChat() async {
        isLoading = true
        errorMessage = nil
        do {
            // Load round and membership in parallel
            async let roundData = roundsRepository.fetchRound(id: roundId)
            async let membershipData = roundsRepository.fetchMembershipStatus(roundId: roundId)
            async let membersData = roundsRepository.fetchMembers(roundId: roundId)

            let fetchedRound = try await roundData
            let membership = try await membershipData
            let members = try await membersData

            round = fetchedRound
            canSendMessages = membership?.status == .accepted || membership?.role == .host

            // Build list of UIDs to preload
            var uidsToPreload = Set<String>()

            // Always include host
            if let hostUid = fetchedRound?.hostUid {
                uidsToPreload.insert(hostUid)
            }

            // Always include current user (for showing own messages)
            if let currentUid = currentUid() {
                uidsToPreload.insert(currentUid)
            }

            // Include all accepted members
            let memberUids = members.filter { $0.status == .accepted }.map { $0.uid }
            uidsToPreload.formUnion(memberUids)

            // Preload all profiles in parallel
            await preloadProfiles(for: Array(uidsToPreload))
        } catch {
            errorMessage = "Failed to load round: \(error.localizedDescription)"
        }
        isLoading = false
        subscribeToMessages()
    }

    private func preloadProfiles(for uids: [String]) async {
        let profileResults = await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in uids where senderProfiles[uid] == nil {
                group.addTask {
                    let profile = try? await self.profileRepository.fetchPublicProfile(uid: uid)
                    return (uid, profile)
                }
            }

            var profiles: [String: PublicProfile] = [:]
            for await (uid, profile) in group {
                if let profile = profile {
                    profiles[uid] = profile
                }
            }
            return profiles
        }

        for (uid, profile) in profileResults {
            senderProfiles[uid] = profile
        }
    }
    
    private func subscribeToMessages() {
        chatRepository.subscribeToMessages(roundId: roundId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "Chat connection lost: \(error.localizedDescription)"
                }
            } receiveValue: { [weak self] serverMessages in
                self?.handleServerMessages(serverMessages)
            }
            .store(in: &cancellables)
    }
    
    private func handleServerMessages(_ serverMessages: [ChatMessage]) {
        // Merge server messages with pending (optimistic) messages
        var merged = serverMessages
        
        // Remove any pending messages that now appear in server messages
        for serverMsg in serverMessages {
            pendingMessages.removeValue(forKey: serverMsg.clientNonce)
        }
        
        // Add remaining pending messages at the end
        for (_, pendingMsg) in pendingMessages {
            if !merged.contains(where: { $0.clientNonce == pendingMsg.clientNonce }) {
                merged.append(pendingMsg)
            }
        }
        
        // Sort by createdAt
        merged.sort { $0.createdAt < $1.createdAt }
        
        messages = merged
        
        // Update pagination cursor (oldest message)
        if let oldest = serverMessages.first {
            oldestMessageCursor = ChatPageCursor(from: oldest)
        }
        
        // Fetch profiles for new senders
        Task { await fetchMissingProfiles(for: merged) }
    }
    
    private func fetchMissingProfiles(for messages: [ChatMessage]) async {
        let senderUids = Set(messages.map { $0.senderUid })
        let missingUids = senderUids.filter { senderProfiles[$0] == nil && $0 != "system" }

        guard !missingUids.isEmpty else { return }

        // Fetch all missing profiles in parallel using TaskGroup
        let profileResults = await withTaskGroup(of: (String, PublicProfile?).self) { group in
            for uid in missingUids {
                group.addTask {
                    let profile = try? await self.profileRepository.fetchPublicProfile(uid: uid)
                    return (uid, profile)
                }
            }

            var profiles: [String: PublicProfile] = [:]
            for await (uid, profile) in group {
                if let profile = profile {
                    profiles[uid] = profile
                }
            }
            return profiles
        }

        // Update all profiles at once (prevents UI flickering)
        for (uid, profile) in profileResults {
            senderProfiles[uid] = profile
        }
    }
    
    /// Get photo URL for a sender
    func senderPhotoUrl(for uid: String) -> String? {
        senderProfiles[uid]?.photoUrls.first
    }

    // MARK: - Photo Handling

    /// Load selected photo from PhotosPicker
    func loadPhoto() async {
        guard let selectedPhoto = selectedPhoto else { return }

        do {
            if let data = try await selectedPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photoImage = image
            }
        } catch {
            errorMessage = "Failed to load photo: \(error.localizedDescription)"
        }

        // Clear selection after loading
        self.selectedPhoto = nil
    }

    /// Remove the selected photo
    func removePhoto() {
        photoImage = nil
        selectedPhoto = nil
    }

    /// Upload photo and get URL
    private func uploadPhoto() async throws -> String? {
        guard let image = photoImage else { return nil }
        guard let data = image.compressedJPEGData(maxDimension: 1080, quality: 0.8) else {
            throw ChatError.sendFailed(underlying: StorageError.invalidImage)
        }

        isUploadingPhoto = true
        uploadProgress = 0.3

        let url = try await storageService.uploadChatPhoto(data, roundId: roundId, messageId: nil)

        uploadProgress = 1.0
        isUploadingPhoto = false

        return url
    }

    // MARK: - Load Older Messages
    
    func loadOlderMessages() async {
        guard hasMoreMessages, !isLoadingMore else { return }
        
        isLoadingMore = true
        
        do {
            let olderMessages = try await chatRepository.fetchMessages(
                roundId: roundId,
                limit: ChatConstants.defaultPageSize,
                before: oldestMessageCursor
            )
            
            if olderMessages.isEmpty {
                hasMoreMessages = false
            } else {
                // Prepend older messages
                messages = olderMessages + messages
                
                // Update cursor
                if let oldest = olderMessages.first {
                    oldestMessageCursor = ChatPageCursor(from: oldest)
                }
            }
        } catch {
            print("Failed to load older messages: \(error)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Send Message

    func sendMessage() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !text.isEmpty
        let hasPhoto = photoImage != nil

        // Validation: must have text OR photo
        guard hasText || hasPhoto, canSendMessages else { return }

        let clientNonce = UUID().uuidString
        guard let uid = currentUid() else { return }

        // Clear composer immediately
        let messageCopy = text
        let photoCopy = photoImage
        composerText = ""
        photoImage = nil
        isSending = true

        // Upload photo first if present
        var photoUrl: String?
        do {
            if photoCopy != nil {
                // Restore photo temporarily for upload
                photoImage = photoCopy
                photoUrl = try await uploadPhoto()
                photoImage = nil  // Clear after upload
            }
        } catch {
            // Restore on upload failure
            composerText = messageCopy
            photoImage = photoCopy
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            isSending = false
            return
        }

        // Create optimistic message
        var optimisticMessage = ChatMessage(
            id: nil,
            roundId: roundId,
            senderUid: uid,
            text: hasText ? messageCopy : "",  // Empty string if photo-only
            type: .text,
            clientNonce: clientNonce,
            createdAt: Date(),
            photoUrl: photoUrl,
            sendState: .sending
        )

        // Add to pending and display
        pendingMessages[clientNonce] = optimisticMessage
        messages.append(optimisticMessage)

        // Send to server
        do {
            let sentMessage = try await chatRepository.sendMessage(
                roundId: roundId,
                text: hasText ? messageCopy : "",
                clientNonce: clientNonce,
                photoUrl: photoUrl
            )

            // Remove from pending (server message will arrive via subscription)
            pendingMessages.removeValue(forKey: clientNonce)

            // Update optimistic message to sent state
            if let index = messages.firstIndex(where: { $0.clientNonce == clientNonce }) {
                messages[index] = sentMessage
            }
        } catch {
            // Mark as failed
            optimisticMessage.sendState = .failed
            pendingMessages[clientNonce] = optimisticMessage

            if let index = messages.firstIndex(where: { $0.clientNonce == clientNonce }) {
                messages[index] = optimisticMessage
            }

            errorMessage = error.localizedDescription
        }

        isSending = false
    }
    
    func retryMessage(_ message: ChatMessage) async {
        guard message.sendState == .failed else { return }
        pendingMessages.removeValue(forKey: message.clientNonce)
        messages.removeAll { $0.clientNonce == message.clientNonce }
        composerText = message.text
        await sendMessage()
    }
    
    func reportMessage(_ message: ChatMessage, reason: String) async {
        guard let messageId = message.id else { return }
        do { try await chatRepository.reportMessage(roundId: roundId, messageId: messageId, reason: reason) }
        catch { errorMessage = "Failed to report message" }
    }
    
    func isOwnMessage(_ message: ChatMessage) -> Bool { message.senderUid == currentUid() }
}

