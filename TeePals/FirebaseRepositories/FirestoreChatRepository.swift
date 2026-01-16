import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of ChatRepository.
/// Provides real-time chat functionality for round-scoped group chat.
final class FirestoreChatRepository: ChatRepository {
    
    private let db = Firestore.firestore()
    private let profileRepository: ProfileRepository
    
    // Rate limiting
    private var lastSendTime: Date?
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    init(profileRepository: ProfileRepository) {
        self.profileRepository = profileRepository
    }
    
    // MARK: - Real-time Subscription
    
    func subscribeToMessages(roundId: String) -> AnyPublisher<[ChatMessage], Error> {
        let subject = PassthroughSubject<[ChatMessage], Error>()
        
        let query = db.collection(FirestoreCollection.rounds)
            .document(roundId)
            .collection(FirestoreCollection.messages)
            .order(by: "createdAt", descending: false)
            .limit(toLast: ChatConstants.defaultPageSize)
        
        let listener = query.addSnapshotListener { snapshot, error in
            if let error = error {
                subject.send(completion: .failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                subject.send([])
                return
            }
            
            let messages = documents.compactMap { doc -> ChatMessage? in
                try? self.decodeMessage(from: doc.data(), id: doc.documentID, roundId: roundId)
            }
            
            subject.send(messages)
        }
        
        // Return publisher that cleans up listener on cancellation
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fetch (Pagination)
    
    func fetchMessages(
        roundId: String,
        limit: Int,
        before: ChatPageCursor?
    ) async throws -> [ChatMessage] {
        var query: Query = db.collection(FirestoreCollection.rounds)
            .document(roundId)
            .collection(FirestoreCollection.messages)
            .order(by: "createdAt", descending: true)
        
        // Pagination: fetch messages before cursor
        if let cursor = before {
            query = query.start(after: [Timestamp(date: cursor.lastMessageDate)])
        }
        
        query = query.limit(to: limit)
        
        let snapshot = try await query.getDocuments()
        
        let messages = snapshot.documents.compactMap { doc -> ChatMessage? in
            try? decodeMessage(from: doc.data(), id: doc.documentID, roundId: roundId)
        }
        
        // Return in chronological order (oldest first)
        return messages.reversed()
    }
    
    // MARK: - Send Message
    
    func sendMessage(
        roundId: String,
        text: String,
        clientNonce: String,
        photoUrl: String?
    ) async throws -> ChatMessage {
        guard let uid = currentUid else {
            throw ChatError.notAuthenticated
        }
        
        // Validate message length
        guard text.count <= ChatConstants.maxMessageLength else {
            throw ChatError.messageTooLong
        }
        
        // Client-side rate limiting
        if let lastSend = lastSendTime,
           Date().timeIntervalSince(lastSend) < ChatConstants.rateLimitIntervalSeconds {
            throw ChatError.rateLimited
        }
        
        // Check for duplicate (idempotency)
        let existingQuery = try await db.collection(FirestoreCollection.rounds)
            .document(roundId)
            .collection(FirestoreCollection.messages)
            .whereField("clientNonce", isEqualTo: clientNonce)
            .limit(to: 1)
            .getDocuments()
        
        if !existingQuery.documents.isEmpty {
            // Already sent - return existing message
            if let doc = existingQuery.documents.first,
               let existing = try? decodeMessage(from: doc.data(), id: doc.documentID, roundId: roundId) {
                return existing
            }
            throw ChatError.duplicateMessage
        }
        
        // Get sender profile for denormalized fields
        let profile = try? await profileRepository.fetchPublicProfile(uid: uid)
        
        // Build message data
        var data: [String: Any] = [
            "senderUid": uid,
            "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
            "type": MessageType.text.rawValue,
            "clientNonce": clientNonce,
            "senderNickname": profile?.nickname ?? "Unknown",
            "senderPhotoUrl": profile?.photoUrls.first ?? "",
            "createdAt": FieldValue.serverTimestamp()
        ]

        // Add photoUrl if present
        if let photoUrl = photoUrl {
            data["photoUrl"] = photoUrl
        }
        
        // Write to Firestore
        let docRef = try await db.collection(FirestoreCollection.rounds)
            .document(roundId)
            .collection(FirestoreCollection.messages)
            .addDocument(data: data)
        
        // Update rate limit tracker
        lastSendTime = Date()
        
        // Return the sent message
        return ChatMessage(
            id: docRef.documentID,
            roundId: roundId,
            senderUid: uid,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            type: .text,
            clientNonce: clientNonce,
            createdAt: Date(),
            photoUrl: photoUrl,
            senderNickname: profile?.nickname,
            senderPhotoUrl: profile?.photoUrls.first,
            sendState: .sent
        )
    }
    
    // MARK: - System Message
    
    func sendSystemMessage(
        roundId: String,
        template: SystemMessageTemplate
    ) async throws {
        guard let uid = currentUid else {
            throw ChatError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "senderUid": uid,
            "text": template.text,
            "type": MessageType.system.rawValue,
            "clientNonce": UUID().uuidString,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection(FirestoreCollection.rounds)
            .document(roundId)
            .collection(FirestoreCollection.messages)
            .addDocument(data: data)
    }
    
    // MARK: - Report Message
    
    func reportMessage(
        roundId: String,
        messageId: String,
        reason: String
    ) async throws {
        guard let uid = currentUid else {
            throw ChatError.notAuthenticated
        }
        
        let reportData: [String: Any] = [
            "roundId": roundId,
            "messageId": messageId,
            "reporterUid": uid,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // Write to reports collection
        try await db.collection("reports").addDocument(data: reportData)
    }

    // MARK: - Chat Metadata

    func fetchChatMetadata(roundId: String) async throws -> ChatMetadata? {
        guard let uid = currentUid else {
            throw ChatError.notAuthenticated
        }

        let doc = try await db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection(FirestoreCollection.chatMetadata).document(uid)
            .getDocument()

        guard doc.exists else { return nil }
        return try doc.data(as: ChatMetadata.self)
    }

    func markChatAsRead(roundId: String) async throws {
        guard let uid = currentUid else {
            throw ChatError.notAuthenticated
        }

        try await db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection(FirestoreCollection.chatMetadata).document(uid)
            .setData([
                "uid": uid,
                "lastReadAt": FieldValue.serverTimestamp(),
                "unreadCount": 0
            ], merge: true)
    }

    func setChatMuted(roundId: String, isMuted: Bool) async throws {
        guard let uid = currentUid else {
            throw ChatError.notAuthenticated
        }

        try await db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection(FirestoreCollection.chatMetadata).document(uid)
            .setData([
                "uid": uid,
                "isMuted": isMuted
            ], merge: true)
    }

    func getTotalChatUnreadCount() async throws -> Int {
        guard let uid = currentUid else { return 0 }

        // Query all rounds where user is accepted member
        let membershipSnapshot = try await db
            .collectionGroup(FirestoreCollection.members)
            .whereField("uid", isEqualTo: uid)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments()

        var totalUnread = 0

        // For each round, fetch chat metadata
        for memberDoc in membershipSnapshot.documents {
            guard let roundId = memberDoc.reference.parent.parent?.documentID else { continue }

            let metadataDoc = try await db
                .collection(FirestoreCollection.rounds).document(roundId)
                .collection(FirestoreCollection.chatMetadata).document(uid)
                .getDocument()

            if let metadata = try? metadataDoc.data(as: ChatMetadata.self) {
                totalUnread += metadata.unreadCount
            }
        }

        return totalUnread
    }

    func observeTotalChatUnreadCount() -> AsyncStream<Int> {
        AsyncStream { continuation in
            guard currentUid != nil else {
                continuation.yield(0)
                continuation.finish()
                return
            }

            // Note: This is a simplified polling implementation
            // In production, consider using a denormalized count in user doc
            let task = Task {
                while !Task.isCancelled {
                    if let count = try? await getTotalChatUnreadCount() {
                        continuation.yield(count)
                    }
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func clearAllChatUnreadCounts() async throws {
        guard let uid = currentUid else {
            throw ChatError.notAuthenticated
        }

        // Query all rounds where user is accepted member
        let membershipSnapshot = try await db
            .collectionGroup(FirestoreCollection.members)
            .whereField("uid", isEqualTo: uid)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments()

        let batch = db.batch()

        // For each round, reset chat metadata unread count
        for memberDoc in membershipSnapshot.documents {
            guard let roundId = memberDoc.reference.parent.parent?.documentID else { continue }

            let metadataRef = db
                .collection(FirestoreCollection.rounds).document(roundId)
                .collection(FirestoreCollection.chatMetadata).document(uid)

            batch.setData([
                "uid": uid,
                "unreadCount": 0,
                "lastReadAt": FieldValue.serverTimestamp()
            ], forDocument: metadataRef, merge: true)
        }

        try await batch.commit()
    }

    // MARK: - Decoding
    
    private func decodeMessage(from data: [String: Any], id: String, roundId: String) throws -> ChatMessage {
        guard let senderUid = data["senderUid"] as? String,
              let text = data["text"] as? String,
              let typeRaw = data["type"] as? String,
              let type = MessageType(rawValue: typeRaw),
              let clientNonce = data["clientNonce"] as? String else {
            throw NSError(domain: "ChatDecode", code: -1)
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let photoUrl = data["photoUrl"] as? String
        let senderNickname = data["senderNickname"] as? String
        let senderPhotoUrl = data["senderPhotoUrl"] as? String

        return ChatMessage(
            id: id,
            roundId: roundId,
            senderUid: senderUid,
            text: text,
            type: type,
            clientNonce: clientNonce,
            createdAt: createdAt,
            photoUrl: photoUrl,
            senderNickname: senderNickname,
            senderPhotoUrl: senderPhotoUrl,
            sendState: .sent
        )
    }
}

