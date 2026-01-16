import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Helper for creating test data in development.
/// ⚠️ FOR TESTING ONLY - Do not use in production code.
struct TestDataHelper {

    // MARK: - Feedback Notifications

    /// Creates a feedback reminder notification for the current user (for testing).
    /// - Parameters:
    ///   - roundId: The round ID
    ///   - courseName: Name of the golf course
    ///   - daysAgo: How many days ago the notification was created (default: 0 for now)
    static func createFeedbackNotification(
        roundId: String,
        courseName: String,
        daysAgo: Int = 0
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw TestDataError.notAuthenticated
        }

        let db = Firestore.firestore()
        let createdAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!

        let data: [String: Any] = [
            "type": "feedbackReminder",
            "targetId": roundId,
            "targetType": "round",
            "title": "Rate your playing partners",
            "body": "You played at \(courseName). Share your experience!",
            "isRead": false,
            "createdAt": Timestamp(date: createdAt),
            "metadata": [
                "courseName": courseName
            ]
        ]

        try await db
            .collection("notifications").document(uid)
            .collection("items").document()
            .setData(data)

        print("✅ Created feedback notification for round: \(roundId)")
    }

    /// Creates a completed round (for testing feedback flow).
    /// - Parameters:
    ///   - roundId: The round ID (optional, generates UUID if not provided)
    ///   - courseName: Name of the golf course
    ///   - hostUid: The host UID (defaults to current user)
    /// - Returns: The round ID
    @discardableResult
    static func createCompletedRound(
        roundId: String? = nil,
        courseName: String = "Test Golf Course",
        hostUid: String? = nil
    ) async throws -> String {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            throw TestDataError.notAuthenticated
        }

        let db = Firestore.firestore()
        let finalRoundId = roundId ?? UUID().uuidString
        let finalHostUid = hostUid ?? currentUid

        // Create round document
        let roundData: [String: Any] = [
            "hostUid": finalHostUid,
            "title": "Test Round",
            "visibility": "public",
            "joinPolicy": "instant",
            "courseCandidates": [[
                "name": courseName,
                "cityLabel": "Test City, CA",
                "location": [
                    "latitude": 37.7749,
                    "longitude": -122.4194
                ]
            ]],
            "chosenCourse": [
                "name": courseName,
                "cityLabel": "Test City, CA",
                "location": [
                    "latitude": 37.7749,
                    "longitude": -122.4194
                ]
            ],
            "teeTimeCandidates": [Timestamp(date: Date())],
            "chosenTeeTime": Timestamp(date: Date()),
            "maxPlayers": 4,
            "acceptedCount": 1,
            "requestCount": 0,
            "status": "completed",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("rounds").document(finalRoundId).setData(roundData)

        // Add current user as accepted member
        let memberData: [String: Any] = [
            "uid": currentUid,
            "status": "accepted",
            "role": finalHostUid == currentUid ? "host" : "member",
            "joinedAt": FieldValue.serverTimestamp()
        ]

        try await db
            .collection("rounds").document(finalRoundId)
            .collection("members").document(currentUid)
            .setData(memberData)

        print("✅ Created completed round: \(finalRoundId)")
        return finalRoundId
    }

    /// Creates multiple feedback notifications for testing.
    static func createSampleFeedbackNotifications() async throws {
        try await createFeedbackNotification(
            roundId: UUID().uuidString,
            courseName: "Pebble Beach Golf Links",
            daysAgo: 0
        )

        try await createFeedbackNotification(
            roundId: UUID().uuidString,
            courseName: "Augusta National Golf Club",
            daysAgo: 0
        )

        try await createFeedbackNotification(
            roundId: UUID().uuidString,
            courseName: "St Andrews Old Course",
            daysAgo: 0
        )

        print("✅ Created 3 sample feedback notifications")
    }

    /// Deletes all feedback notifications for current user (cleanup).
    static func clearFeedbackNotifications() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw TestDataError.notAuthenticated
        }

        let db = Firestore.firestore()
        let snapshot = try await db
            .collection("notifications").document(uid)
            .collection("items")
            .whereField("type", isEqualTo: "feedbackReminder")
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()

        print("✅ Cleared all feedback notifications")
    }

    // MARK: - Trust Badges

    /// Grants trust badges to the current user for testing
    /// - Parameter badges: Which badges to grant (defaults to all)
    static func grantTrustBadges(
        onTime: Bool = true,
        respectful: Bool = true,
        wellMatched: Bool = true,
        communicator: Bool = true,
        trustedRegular: Bool = false
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw TestDataError.notAuthenticated
        }

        let db = Firestore.firestore()

        var updateData: [String: Any] = [
            "hasOnTimeBadge": onTime,
            "hasRespectfulBadge": respectful,
            "hasWellMatchedBadge": wellMatched,
            "hasCommunicatorBadge": communicator,
            "hasTrustedRegularBadge": trustedRegular,
            "completedRoundsCount": trustedRegular ? 20 : 5,
            "recentWouldPlayAgainPct": 0.95,
            "lifetimeWouldPlayAgainPct": 0.92
        ]

        try await db
            .collection("profiles_public")
            .document(uid)
            .updateData(updateData)

        print("✅ Granted trust badges - check your profile!")
    }

    /// Removes all trust badges from current user
    static func clearTrustBadges() async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw TestDataError.notAuthenticated
        }

        let db = Firestore.firestore()

        let updateData: [String: Any] = [
            "hasOnTimeBadge": false,
            "hasRespectfulBadge": false,
            "hasWellMatchedBadge": false,
            "hasCommunicatorBadge": false,
            "hasTrustedRegularBadge": false,
            "completedRoundsCount": 0,
            "recentWouldPlayAgainPct": 0.0,
            "lifetimeWouldPlayAgainPct": 0.0
        ]

        try await db
            .collection("profiles_public")
            .document(uid)
            .updateData(updateData)

        print("✅ Cleared all trust badges")
    }
}

// MARK: - Test Data Error

enum TestDataError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Must be signed in to create test data"
        }
    }
}
