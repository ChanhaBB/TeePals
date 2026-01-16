import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of ActivityRoundsService.
final class FirestoreActivityRoundsService: ActivityRoundsService {
    
    private let db = Firestore.firestore()
    private let roundsDecoder: FirestoreRoundDecoder
    
    init(roundsDecoder: FirestoreRoundDecoder = FirestoreRoundDecoder()) {
        self.roundsDecoder = roundsDecoder
    }
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Hosting Rounds
    
    func fetchHostingRounds(dateRange: DateRangeOption?) async throws -> [Round] {
        guard let uid = currentUid else {
            throw ActivityRoundsError.notAuthenticated
        }
        
        var query: Query = db.collection(FirestoreCollection.rounds)
            .whereField("hostUid", isEqualTo: uid)
            .whereField("status", in: ["open", "full"])
        
        // Apply date filter if provided
        if let dateRange = dateRange {
            query = query
                .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: dateRange.startDate))
                .whereField("startTime", isLessThan: Timestamp(date: dateRange.endDate))
        }
        
        query = query
            .order(by: "startTime", descending: false)
            .limit(to: 100)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? roundsDecoder.decode(from: doc.data(), id: doc.documentID)
        }
    }
    
    // MARK: - Requested Rounds
    
    func fetchRequestedRounds(dateRange: DateRangeOption?) async throws -> [RoundRequest] {
        guard let uid = currentUid else {
            throw ActivityRoundsError.notAuthenticated
        }
        
        // Step 1: Get all rounds where user has a membership document
        // We use collectionGroup query on "members" subcollection
        let membershipsSnapshot = try await db.collectionGroup(FirestoreCollection.members)
            .whereField("uid", isEqualTo: uid)
            .whereField("role", isEqualTo: "member") // Not host
            .getDocuments()
        
        // Step 2: Extract round IDs and membership data
        var roundMemberships: [(roundId: String, status: MemberStatus, createdAt: Date)] = []
        
        for doc in membershipsSnapshot.documents {
            // Path: rounds/{roundId}/members/{memberId}
            let pathComponents = doc.reference.path.components(separatedBy: "/")
            guard pathComponents.count >= 2,
                  let roundIdIndex = pathComponents.firstIndex(of: "rounds"),
                  roundIdIndex + 1 < pathComponents.count else { continue }
            
            let roundId = pathComponents[roundIdIndex + 1]
            let data = doc.data()
            
            guard let statusRaw = data["status"] as? String,
                  let status = MemberStatus(rawValue: statusRaw) else { continue }
            
            // Filter out withdrawn, removed, and declined statuses
            guard status != .left && status != .removed && status != .declined else { continue }
            
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            
            roundMemberships.append((roundId, status, createdAt))
        }
        
        guard !roundMemberships.isEmpty else { return [] }
        
        // Step 3: Fetch round documents
        // Firestore "in" query supports max 30 items; chunk if needed
        var allRequests: [RoundRequest] = []
        let chunks = roundMemberships.chunked(into: 30)
        
        for chunk in chunks {
            let roundIds = chunk.map { $0.roundId }
            let roundsSnapshot = try await db.collection(FirestoreCollection.rounds)
                .whereField(FieldPath.documentID(), in: roundIds)
                .getDocuments()
            
            for doc in roundsSnapshot.documents {
                guard let round = try? roundsDecoder.decode(from: doc.data(), id: doc.documentID) else { continue }
                
                // Apply date filter
                if let dateRange = dateRange, let startTime = round.startTime {
                    if startTime < dateRange.startDate || startTime >= dateRange.endDate {
                        continue
                    }
                }
                
                // Find matching membership
                guard let membership = chunk.first(where: { $0.roundId == doc.documentID }) else { continue }
                
                // Skip canceled rounds
                if round.status == .canceled { continue }
                
                let request = RoundRequest(
                    round: round,
                    status: membership.status,
                    requestedAt: membership.createdAt
                )
                allRequests.append(request)
            }
        }
        
        // Sort: pending first, then by startTime
        allRequests.sort { lhs, rhs in
            if lhs.isPending != rhs.isPending {
                return lhs.isPending // Pending first
            }
            let lhsTime = lhs.round.startTime ?? .distantFuture
            let rhsTime = rhs.round.startTime ?? .distantFuture
            return lhsTime < rhsTime
        }
        
        return allRequests
    }
}

// MARK: - Error

enum ActivityRoundsError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to view your rounds."
        }
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

