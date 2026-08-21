import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of ReportRepository.
final class FirestoreReportRepository: ReportRepository {

    private let db = Firestore.firestore()

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    func submitReport(report: Report) async throws {
        guard currentUid != nil else {
            throw ReportRepositoryError.notAuthenticated
        }

        let ref = db.collection(FirestoreCollection.reports).document()
        try ref.setData(from: report)
    }

    func blockUser(blockedUid: String) async throws {
        guard let currentUid = currentUid else {
            throw ReportRepositoryError.notAuthenticated
        }

        guard currentUid != blockedUid else {
            throw ReportRepositoryError.cannotBlockSelf
        }

        let ref = db
            .collection(FirestoreCollection.blocks)
            .document(currentUid)
            .collection(FirestoreCollection.blocked)
            .document(blockedUid)

        let blockedUser = BlockedUser(blockedAt: Date())
        try ref.setData(from: blockedUser)
    }
}

enum ReportRepositoryError: LocalizedError {
    case notAuthenticated
    case cannotBlockSelf

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .cannotBlockSelf:
            return "You cannot block yourself."
        }
    }
}
