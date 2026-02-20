import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of FollowingRoundsService.
/// Handles chunked queries for users following >10 people.
final class FirestoreFollowingRoundsService: FollowingRoundsService {
    
    private let db = Firestore.firestore()
    private let socialRepository: SocialRepository
    private let roundsDecoder: FirestoreRoundDecoder
    
    private let maxHostsPerQuery = 10 // Firestore "in" limit
    private let maxResultsPerChunk = 200
    
    init(
        socialRepository: SocialRepository,
        roundsDecoder: FirestoreRoundDecoder = FirestoreRoundDecoder()
    ) {
        self.socialRepository = socialRepository
        self.roundsDecoder = roundsDecoder
    }
    
    func fetchFollowingHostedRounds(dateRange: DateRangeOption) async throws -> [Round] {
        // Get list of users the current user follows
        let followingUids = try await socialRepository.getFollowing()
        
        guard !followingUids.isEmpty else { return [] }
        
        // Chunk into groups of 10 (Firestore "in" query limit)
        let chunks = followingUids.chunked(into: maxHostsPerQuery)
        
        // Fetch rounds from each chunk concurrently
        var allRounds: [Round] = []
        var seenIds = Set<String>()
        
        try await withThrowingTaskGroup(of: [Round].self) { group in
            for chunk in chunks {
                group.addTask { [self] in
                    try await self.fetchRoundsForHosts(
                        hostUids: chunk,
                        dateRange: dateRange
                    )
                }
            }
            
            for try await rounds in group {
                for round in rounds {
                    guard let id = round.id, !seenIds.contains(id) else { continue }
                    seenIds.insert(id)
                    allRounds.append(round)
                }
            }
        }
        
        // Sort by startTime ascending
        allRounds.sort { lhs, rhs in
            let lhsTime = lhs.startTime ?? .distantFuture
            let rhsTime = rhs.startTime ?? .distantFuture
            return lhsTime < rhsTime
        }
        
        return allRounds
    }
    
    // MARK: - Private Helpers
    
    private func fetchRoundsForHosts(hostUids: [String], dateRange: DateRangeOption) async throws -> [Round] {
        guard !hostUids.isEmpty else { return [] }
        
        let query = db.collection(FirestoreCollection.rounds)
            .whereField("hostUid", in: hostUids)
            .whereField("status", isEqualTo: "open")
            .whereField("visibility", isEqualTo: "public")
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: dateRange.startDate))
            .whereField("startTime", isLessThan: Timestamp(date: dateRange.endDate))
            .order(by: "startTime", descending: false)
            .limit(to: maxResultsPerChunk)
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? roundsDecoder.decode(from: doc.data(), id: doc.documentID)
        }
    }
}


