import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of TrustRepository.
/// Handles all feedback and trust system operations.
final class FirestoreTrustRepository: TrustRepository {

    private let db = Firestore.firestore()

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Feedback Submission

    func submitRoundFeedback(
        roundId: String,
        roundSafetyOK: Bool,
        skillLevelsAccurate: Bool?
    ) async throws -> RoundFeedback {
        guard let uid = currentUid else {
            throw TrustError.notAuthenticated
        }

        // Check if feedback already submitted
        let existingDoc = try await db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection("feedback").document(uid)
            .getDocument()

        if existingDoc.exists {
            throw TrustError.feedbackAlreadySubmitted
        }

        // Check if user is a participant
        let memberDoc = try await db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection(FirestoreCollection.members).document(uid)
            .getDocument()

        guard memberDoc.exists else {
            throw TrustError.notRoundParticipant
        }

        // Create feedback document
        let feedback = RoundFeedback(
            id: uid,
            roundId: roundId,
            reviewerUid: uid,
            roundSafetyOK: roundSafetyOK,
            skillLevelsAccurate: skillLevelsAccurate,
            submittedAt: Date()
        )

        var data: [String: Any] = [
            "roundId": roundId,
            "reviewerUid": uid,
            "roundSafetyOK": roundSafetyOK,
            "submittedAt": FieldValue.serverTimestamp()
        ]

        if let skillAccurate = skillLevelsAccurate {
            data["skillLevelsAccurate"] = skillAccurate
        }

        try await db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection("feedback").document(uid)
            .setData(data)

        // Remove from pending feedback
        try? await db
            .collection("pendingFeedback").document(uid)
            .collection("items").document(roundId)
            .delete()

        return feedback
    }

    func submitEndorsements(
        roundId: String,
        endorsements: [(targetUid: String, wouldPlayAgain: Bool)]
    ) async throws {
        guard let uid = currentUid else {
            throw TrustError.notAuthenticated
        }

        guard !endorsements.isEmpty else { return }

        // Submit all endorsements in a batch
        let batch = db.batch()

        for endorsement in endorsements where endorsement.wouldPlayAgain {
            let docRef = db
                .collection(FirestoreCollection.rounds).document(roundId)
                .collection("endorsements")
                .document()

            let data: [String: Any] = [
                "roundId": roundId,
                "reviewerUid": uid,
                "targetUid": endorsement.targetUid,
                "wouldPlayAgain": true,
                "submittedAt": FieldValue.serverTimestamp()
            ]

            batch.setData(data, forDocument: docRef)
        }

        try await batch.commit()
    }

    func submitIncidentReport(
        roundId: String,
        targetUid: String,
        issueTypes: [IssueType],
        comment: String?
    ) async throws {
        guard let uid = currentUid else {
            throw TrustError.notAuthenticated
        }

        guard !issueTypes.isEmpty else {
            throw TrustError.invalidInput("At least one issue type must be selected")
        }

        // Validate comment length
        if let comment = comment, comment.count > 200 {
            throw TrustError.invalidInput("Comment must be 200 characters or less")
        }

        // Create incident document
        let docRef = db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection("incidents")
            .document()

        var data: [String: Any] = [
            "roundId": roundId,
            "reviewerUid": uid,
            "targetUid": targetUid,
            "issueTypes": issueTypes.map { $0.rawValue },
            "submittedAt": FieldValue.serverTimestamp(),
            "reviewed": false
        ]

        if let comment = comment, !comment.isEmpty {
            data["comment"] = comment
        }

        try await docRef.setData(data)
    }

    // MARK: - Pending Feedback

    func fetchPendingFeedback() async throws -> [PendingFeedback] {
        guard let uid = currentUid else {
            throw TrustError.notAuthenticated
        }

        let snapshot = try await db
            .collection("pendingFeedback").document(uid)
            .collection("items")
            .order(by: "expiresAt", descending: false)
            .getDocuments()

        let now = Date()
        let items = snapshot.documents.compactMap { doc -> PendingFeedback? in
            guard let data = try? doc.data(as: PendingFeedback.self),
                  data.expiresAt > now else { // Filter out expired items
                return nil
            }
            return data
        }

        return items
    }

    func hasFeedbackBeenSubmitted(roundId: String) async throws -> Bool {
        guard let uid = currentUid else {
            throw TrustError.notAuthenticated
        }

        let doc = try await db
            .collection(FirestoreCollection.rounds).document(roundId)
            .collection("feedback").document(uid)
            .getDocument()

        return doc.exists
    }

    func fetchPendingFeedbackItem(roundId: String) async throws -> PendingFeedback? {
        guard let uid = currentUid else {
            throw TrustError.notAuthenticated
        }

        let doc = try await db
            .collection("pendingFeedback").document(uid)
            .collection("items").document(roundId)
            .getDocument()

        guard doc.exists else { return nil }

        let item = try doc.data(as: PendingFeedback.self)

        // Return nil if expired
        if item.expiresAt <= Date() {
            return nil
        }

        return item
    }
}
