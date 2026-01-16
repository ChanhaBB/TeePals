import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore implementation of RoundsRepository.
final class FirestoreRoundsRepository: RoundsRepository {
    
    private let db = Firestore.firestore()
    
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Round CRUD
    
    func createRound(_ round: Round) async throws -> Round {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }
        
        let docRef = db.collection(FirestoreCollection.rounds).document()
        var newRound = round
        newRound.id = docRef.documentID
        
        let data = try encodeRound(newRound, hostUid: uid, isNew: true)
        try await docRef.setData(data)
        
        // Add host as accepted member
        let memberRef = docRef.collection(FirestoreCollection.members).document(uid)
        let memberData: [String: Any] = [
            "uid": uid,
            "role": MemberRole.host.rawValue,
            "status": MemberStatus.accepted.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await memberRef.setData(memberData)
        
        return newRound
    }
    
    func fetchRound(id: String) async throws -> Round? {
        let docRef = db.collection(FirestoreCollection.rounds).document(id)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        
        return try decodeRound(from: data, id: snapshot.documentID)
    }
    
    func fetchRounds(
        filters: RoundFilters,
        limit: Int,
        lastRound: Round?
    ) async throws -> [Round] {
        var query: Query = db.collection(FirestoreCollection.rounds)
        
        // Determine if we should filter by city
        // Skip cityKey filter when radius is 0 (Any) to show rounds from all locations
        let shouldFilterByCity = filters.radiusMiles > 0 && filters.cityKey != nil && !filters.cityKey!.isEmpty
        
        // Apply cityKey filter only when distance filtering is active
        if shouldFilterByCity, let cityKey = filters.cityKey {
            query = query.whereField("cityKey", isEqualTo: cityKey)
        }
        
        // Apply status filter
        if let status = filters.status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }
        
        // Apply visibility filter (MVP: only public)
        if let visibility = filters.visibility {
            query = query.whereField("visibility", isEqualTo: visibility.rawValue)
        } else {
            // Default to public rounds
            query = query.whereField("visibility", isEqualTo: RoundVisibility.public.rawValue)
        }
        
        // Apply host filter (for "my rounds" view)
        if let hostUid = filters.hostUid {
            query = query.whereField("hostUid", isEqualTo: hostUid)
        }
        
        // Apply date range filter (server-side pushdown)
        // Uses composite index when cityKey filter is applied
        if shouldFilterByCity {
            query = query.whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: filters.startTimeMin))
            query = query.whereField("startTime", isLessThan: Timestamp(date: filters.startTimeMax))
            // Order by startTime (soonest first) - required for date range queries
            query = query.order(by: "startTime", descending: false)
        } else {
            // When showing all locations, still filter by date but order by startTime
            query = query.whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: filters.startTimeMin))
            query = query.whereField("startTime", isLessThan: Timestamp(date: filters.startTimeMax))
            query = query.order(by: "startTime", descending: false)
        }
        
        // Pagination
        if let lastRound = lastRound, let lastStartTime = lastRound.startTime {
            query = query.start(after: [Timestamp(date: lastStartTime)])
        }
        
        // Fetch larger batch when showing all locations (no city filter)
        let fetchLimit = shouldFilterByCity ? limit : max(limit, 200)
        query = query.limit(to: fetchLimit)
        
        let snapshot = try await query.getDocuments()
        
        var rounds: [Round] = []
        for doc in snapshot.documents {
            if var round = try? decodeRound(from: doc.data(), id: doc.documentID) {
                // Client-side filtering for full rounds
                if filters.excludeFullRounds && round.isFull {
                    continue
                }
                
                // Client-side distance filtering (required)
                if let centerLocation = filters.centerLocation,
                   let roundLocation = round.displayLocation {
                    let distance = calculateDistance(from: centerLocation, to: roundLocation)
                    
                    // Apply radius filter (0 = any distance)
                    if filters.radiusMiles > 0 && distance > Double(filters.radiusMiles) {
                        continue
                    }
                    
                    round.distanceMiles = distance
                }
                
                rounds.append(round)
            }
        }
        
        // Apply client-side sorting
        rounds = sortRounds(rounds, by: filters.sortBy)
        
        // Trim to requested limit after filtering
        if rounds.count > limit {
            rounds = Array(rounds.prefix(limit))
        }
        
        return rounds
    }
    
    /// Sort rounds based on selected option
    private func sortRounds(_ rounds: [Round], by option: RoundSortOption) -> [Round] {
        switch option {
        case .date:
            return rounds.sorted { ($0.startTime ?? $0.displayTeeTime ?? .distantFuture) < ($1.startTime ?? $1.displayTeeTime ?? .distantFuture) }
        case .distance:
            return rounds.sorted { ($0.distanceMiles ?? Double.infinity) < ($1.distanceMiles ?? Double.infinity) }
        case .newest:
            return rounds.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    func updateRound(_ round: Round) async throws {
        guard let roundId = round.id else {
            throw RoundsRepositoryError.invalidRound
        }
        
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }
        
        // Verify ownership
        let existing = try await fetchRound(id: roundId)
        guard existing?.hostUid == uid else {
            throw RoundsRepositoryError.permissionDenied
        }
        
        let docRef = db.collection(FirestoreCollection.rounds).document(roundId)
        let data = try encodeRound(round, hostUid: uid, isNew: false)
        try await docRef.setData(data, merge: true)
    }
    
    func cancelRound(id: String) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }
        
        let docRef = db.collection(FirestoreCollection.rounds).document(id)
        let snapshot = try await docRef.getDocument()
        
        guard let data = snapshot.data(),
              let hostUid = data["hostUid"] as? String,
              hostUid == uid else {
            throw RoundsRepositoryError.permissionDenied
        }
        
        try await docRef.updateData([
            "status": RoundStatus.canceled.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Membership
    
    func fetchMembers(roundId: String) async throws -> [RoundMember] {
        let snapshot = try await db.collection(FirestoreCollection.rounds)
            .document(roundId)
            .collection(FirestoreCollection.members)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? decodeMember(from: doc.data(), id: doc.documentID)
        }
    }
    
    func requestToJoin(roundId: String) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }
        
        let roundRef = db.collection(FirestoreCollection.rounds).document(roundId)
        let memberRef = roundRef.collection(FirestoreCollection.members).document(uid)
        
        // Check if already a member
        let existing = try await memberRef.getDocument()
        if existing.exists {
            // Check status - allow re-request if removed, left, or declined
            if let data = existing.data(),
               let statusRaw = data["status"] as? String,
               let status = MemberStatus(rawValue: statusRaw) {
                switch status {
                case .accepted, .requested, .invited:
                    // Already an active member or has pending request
                    throw RoundsRepositoryError.alreadyMember
                case .removed, .left, .declined:
                    // Was removed/left/declined - allow to request again
                    break
                }
            } else {
                throw RoundsRepositoryError.alreadyMember
            }
        }
        
        // Create or update request
        let memberData: [String: Any] = [
            "uid": uid,
            "role": MemberRole.member.rawValue,
            "status": MemberStatus.requested.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await memberRef.setData(memberData)
        
        // Note: requestCount is not updated here due to permissions
        // The count can be derived from members subcollection queries
    }
    
    func joinRound(roundId: String) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }
        
        let roundRef = db.collection(FirestoreCollection.rounds).document(roundId)
        let memberRef = roundRef.collection(FirestoreCollection.members).document(uid)
        
        // Check if already a member
        let existing = try await memberRef.getDocument()
        if existing.exists {
            // Check status - allow re-join if removed, left, or declined
            if let data = existing.data(),
               let statusRaw = data["status"] as? String,
               let status = MemberStatus(rawValue: statusRaw) {
                switch status {
                case .accepted, .requested, .invited:
                    // Already an active member or has pending request
                    throw RoundsRepositoryError.alreadyMember
                case .removed, .left, .declined:
                    // Was removed/left/declined - allow to join again
                    break
                }
            } else {
                throw RoundsRepositoryError.alreadyMember
            }
        }
        
        // Check round policy and capacity
        let roundSnapshot = try await roundRef.getDocument()
        guard let roundData = roundSnapshot.data(),
              let policy = roundData["joinPolicy"] as? String,
              policy == JoinPolicy.instant.rawValue else {
            throw RoundsRepositoryError.permissionDenied
        }
        
        let acceptedCount = roundData["acceptedCount"] as? Int ?? 0
        let maxPlayers = roundData["maxPlayers"] as? Int ?? 4
        guard acceptedCount < maxPlayers else {
            throw RoundsRepositoryError.roundFull
        }
        
        // Join immediately
        let memberData: [String: Any] = [
            "uid": uid,
            "role": MemberRole.member.rawValue,
            "status": MemberStatus.accepted.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await memberRef.setData(memberData)
        
        // Note: acceptedCount is not updated here due to permissions
        // The count can be derived from members subcollection queries
    }
    
    func acceptMember(roundId: String, memberUid: String) async throws {
        try await updateMemberStatus(
            roundId: roundId,
            memberUid: memberUid,
            newStatus: .accepted,
            incrementAccepted: true,
            decrementRequests: true
        )
    }
    
    func declineMember(roundId: String, memberUid: String) async throws {
        try await updateMemberStatus(
            roundId: roundId,
            memberUid: memberUid,
            newStatus: .declined,
            decrementRequests: true
        )
    }
    
    func removeMember(roundId: String, memberUid: String) async throws {
        try await updateMemberStatus(
            roundId: roundId,
            memberUid: memberUid,
            newStatus: .removed,
            decrementAccepted: true
        )
    }
    
    func leaveRound(roundId: String) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }
        
        let roundRef = db.collection(FirestoreCollection.rounds).document(roundId)
        let memberRef = roundRef.collection(FirestoreCollection.members).document(uid)
        
        let snapshot = try await memberRef.getDocument()
        guard let data = snapshot.data(),
              let statusRaw = data["status"] as? String,
              let status = MemberStatus(rawValue: statusRaw) else {
            throw RoundsRepositoryError.notMember
        }
        
        // Update member status to left
        try await memberRef.updateData([
            "status": MemberStatus.left.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update counts based on previous status
        var updates: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        if status == .accepted {
            // Was an accepted member, decrement accepted count
            updates["acceptedCount"] = FieldValue.increment(Int64(-1))
        } else if status == .requested {
            // Was a pending request, decrement request count
            updates["requestCount"] = FieldValue.increment(Int64(-1))
        }
        
        if updates.count > 1 {
            try await roundRef.updateData(updates)
        }
    }
    
    func inviteMember(roundId: String, targetUid: String) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }

        let roundRef = db.collection(FirestoreCollection.rounds).document(roundId)

        // Verify user is host OR accepted member
        let roundSnapshot = try await roundRef.getDocument()
        guard let roundData = roundSnapshot.data() else {
            throw RoundsRepositoryError.invalidRound
        }

        let hostUid = roundData["hostUid"] as? String
        let isHost = hostUid == uid

        // If not host, check if accepted member
        if !isHost {
            let memberRef = roundRef.collection(FirestoreCollection.members).document(uid)
            let memberSnapshot = try await memberRef.getDocument()
            guard let memberData = memberSnapshot.data(),
                  let statusRaw = memberData["status"] as? String,
                  statusRaw == MemberStatus.accepted.rawValue else {
                throw RoundsRepositoryError.permissionDenied
            }
        }

        let targetMemberRef = roundRef.collection(FirestoreCollection.members).document(targetUid)

        // Check if already a member (invited, requested, or accepted)
        let existing = try await targetMemberRef.getDocument()
        if existing.exists {
            if let data = existing.data(),
               let statusRaw = data["status"] as? String,
               let status = MemberStatus(rawValue: statusRaw) {
                // Only allow invite if they previously declined, left, or were removed
                switch status {
                case .invited, .requested, .accepted:
                    throw RoundsRepositoryError.alreadyMember
                case .declined, .left, .removed:
                    break  // Allow re-invite
                }
            }
        }

        let memberData: [String: Any] = [
            "uid": targetUid,
            "role": MemberRole.member.rawValue,
            "status": MemberStatus.invited.rawValue,
            "invitedBy": uid,  // Track who sent the invite
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await targetMemberRef.setData(memberData)
    }
    
    func fetchMembershipStatus(roundId: String) async throws -> RoundMember? {
        guard let uid = currentUid else { return nil }

        let memberRef = db.collection(FirestoreCollection.rounds)
            .document(roundId)
            .collection(FirestoreCollection.members)
            .document(uid)

        let snapshot = try await memberRef.getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }

        return try decodeMember(from: data, id: snapshot.documentID)
    }

    // MARK: - Invitations

    func fetchInvitedRounds() async throws -> [Round] {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }

        // Use collectionGroup to query all members subcollections
        let query = db.collectionGroup(FirestoreCollection.members)
            .whereField("uid", isEqualTo: uid)
            .whereField("status", isEqualTo: MemberStatus.invited.rawValue)

        let snapshot = try await query.getDocuments()

        // Extract round IDs from member documents
        var roundIds: [String] = []
        for document in snapshot.documents {
            // Document path is: rounds/{roundId}/members/{uid}
            if let roundId = document.reference.parent.parent?.documentID {
                roundIds.append(roundId)
            }
        }

        // Fetch all invited rounds in parallel
        let rounds = try await withThrowingTaskGroup(of: Round?.self) { group in
            for roundId in roundIds {
                group.addTask {
                    try await self.fetchRound(id: roundId)
                }
            }

            var results: [Round] = []
            for try await round in group {
                if let round = round {
                    results.append(round)
                }
            }
            return results
        }

        // Sort by startTime (soonest first)
        return rounds.sorted { r1, r2 in
            guard let t1 = r1.startTime, let t2 = r2.startTime else { return false }
            return t1 < t2
        }
    }

    func acceptInvite(roundId: String) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }

        let roundRef = db.collection(FirestoreCollection.rounds).document(roundId)
        let memberRef = roundRef.collection(FirestoreCollection.members).document(uid)

        // Verify invitation exists
        let snapshot = try await memberRef.getDocument()
        guard let data = snapshot.data(),
              let statusRaw = data["status"] as? String,
              statusRaw == MemberStatus.invited.rawValue else {
            throw RoundsRepositoryError.notMember
        }

        // Check round capacity
        let roundSnapshot = try await roundRef.getDocument()
        guard let roundData = roundSnapshot.data() else {
            throw RoundsRepositoryError.invalidRound
        }

        let acceptedCount = roundData["acceptedCount"] as? Int ?? 0
        let maxPlayers = roundData["maxPlayers"] as? Int ?? 4
        guard acceptedCount < maxPlayers else {
            throw RoundsRepositoryError.roundFull
        }

        // Update status to accepted
        try await memberRef.updateData([
            "status": MemberStatus.accepted.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        // Increment accepted count
        try await roundRef.updateData([
            "acceptedCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func declineInvite(roundId: String) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }

        let roundRef = db.collection(FirestoreCollection.rounds).document(roundId)
        let memberRef = roundRef.collection(FirestoreCollection.members).document(uid)

        // Verify invitation exists
        let snapshot = try await memberRef.getDocument()
        guard let data = snapshot.data(),
              let statusRaw = data["status"] as? String,
              statusRaw == MemberStatus.invited.rawValue else {
            throw RoundsRepositoryError.notMember
        }

        // Delete the invitation record
        try await memberRef.delete()
    }

    // MARK: - Private Helpers
    
    private func updateMemberStatus(
        roundId: String,
        memberUid: String,
        newStatus: MemberStatus,
        incrementAccepted: Bool = false,
        decrementAccepted: Bool = false,
        decrementRequests: Bool = false
    ) async throws {
        guard let uid = currentUid else {
            throw RoundsRepositoryError.notAuthenticated
        }
        
        // Verify host permission
        let roundRef = db.collection(FirestoreCollection.rounds).document(roundId)
        let roundSnapshot = try await roundRef.getDocument()
        guard let roundData = roundSnapshot.data(),
              let hostUid = roundData["hostUid"] as? String,
              hostUid == uid else {
            throw RoundsRepositoryError.permissionDenied
        }
        
        let memberRef = roundRef.collection(FirestoreCollection.members).document(memberUid)
        try await memberRef.updateData([
            "status": newStatus.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        
        // Update counts
        var updates: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        if incrementAccepted {
            updates["acceptedCount"] = FieldValue.increment(Int64(1))
        }
        if decrementAccepted {
            updates["acceptedCount"] = FieldValue.increment(Int64(-1))
        }
        if decrementRequests {
            updates["requestCount"] = FieldValue.increment(Int64(-1))
        }
        
        if updates.count > 1 {
            try await roundRef.updateData(updates)
        }
    }
    
    private func calculateDistance(from: GeoLocation, to: GeoLocation) -> Double {
        // Haversine formula
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        let earthRadiusMiles = 3958.8
        return earthRadiusMiles * c
    }
}

// MARK: - Encoding

extension FirestoreRoundsRepository {
    
    private func encodeRound(_ round: Round, hostUid: String, isNew: Bool) throws -> [String: Any] {
        var data: [String: Any] = [
            "hostUid": hostUid,
            "title": round.title,
            "visibility": round.visibility.rawValue,
            "joinPolicy": round.joinPolicy.rawValue,
            "maxPlayers": round.maxPlayers,
            "acceptedCount": round.acceptedCount,
            "requestCount": round.requestCount,
            "status": round.status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if isNew {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        
        // Denormalized fields for efficient queries
        if let cityKey = round.cityKey {
            data["cityKey"] = cityKey
        }
        if let startTime = round.startTime {
            data["startTime"] = Timestamp(date: startTime)
        }
        if let lat = round.courseLat {
            data["courseLat"] = lat
        }
        if let lng = round.courseLng {
            data["courseLng"] = lng
        }
        
        // Geo data for geohash-based search
        if let geo = round.geo {
            data["geo"] = [
                "lat": geo.lat,
                "lng": geo.lng,
                "geohash": geo.geohash
            ]
            #if DEBUG
            print("💾 Saving round with geo: lat=\(geo.lat), lng=\(geo.lng), geohash=\(geo.geohash)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ Saving round WITHOUT geo data!")
            #endif
        }
        
        // Encode course candidates
        data["courseCandidates"] = round.courseCandidates.map { candidate in
            [
                "name": candidate.name,
                "cityLabel": candidate.cityLabel,
                "location": GeoPoint(
                    latitude: candidate.location.latitude,
                    longitude: candidate.location.longitude
                )
            ] as [String: Any]
        }
        
        // Encode chosen course
        if let chosen = round.chosenCourse {
            data["chosenCourse"] = [
                "name": chosen.name,
                "cityLabel": chosen.cityLabel,
                "location": GeoPoint(
                    latitude: chosen.location.latitude,
                    longitude: chosen.location.longitude
                )
            ] as [String: Any]
        }
        
        // Encode tee time candidates
        data["teeTimeCandidates"] = round.teeTimeCandidates.map { Timestamp(date: $0) }
        
        // Encode chosen tee time
        if let chosenTime = round.chosenTeeTime {
            data["chosenTeeTime"] = Timestamp(date: chosenTime)
        }
        
        // Encode requirements
        if let req = round.requirements, !req.isEmpty {
            var reqData: [String: Any] = [:]
            if let genders = req.genderAllowed {
                reqData["genderAllowed"] = genders.map { $0.rawValue }
            }
            if let minAge = req.minAge { reqData["minAge"] = minAge }
            if let maxAge = req.maxAge { reqData["maxAge"] = maxAge }
            if let skills = req.skillLevelsAllowed {
                reqData["skillLevelsAllowed"] = skills.map { $0.rawValue }
            }
            if let minScore = req.minAvgScore { reqData["minAvgScore"] = minScore }
            if let maxScore = req.maxAvgScore { reqData["maxAvgScore"] = maxScore }
            if let maxDist = req.maxDistanceMiles { reqData["maxDistanceMiles"] = maxDist }
            data["requirements"] = reqData
        }
        
        // Encode price
        if let price = round.price {
            var priceData: [String: Any] = [
                "type": price.type.rawValue,
                "currency": price.currency
            ]
            if let amount = price.amount { priceData["amount"] = amount }
            if let min = price.min { priceData["min"] = min }
            if let max = price.max { priceData["max"] = max }
            if let note = price.note { priceData["note"] = note }
            data["price"] = priceData
        }
        
        if let priceTier = round.priceTier {
            data["priceTier"] = priceTier.rawValue
        }
        
        if let description = round.description, !description.isEmpty {
            data["description"] = description
        }
        
        return data
    }
}

// MARK: - Decoding

extension FirestoreRoundsRepository {
    
    private func decodeRound(from data: [String: Any], id: String) throws -> Round {
        guard let hostUid = data["hostUid"] as? String,
              let title = data["title"] as? String,
              let visibilityRaw = data["visibility"] as? String,
              let visibility = RoundVisibility(rawValue: visibilityRaw),
              let joinPolicyRaw = data["joinPolicy"] as? String,
              let joinPolicy = JoinPolicy(rawValue: joinPolicyRaw),
              let statusRaw = data["status"] as? String,
              let status = RoundStatus(rawValue: statusRaw) else {
            throw RoundsRepositoryError.decodingFailed
        }
        
        // Decode course candidates
        var courseCandidates: [CourseCandidate] = []
        if let candidatesData = data["courseCandidates"] as? [[String: Any]] {
            for candidateData in candidatesData {
                if let candidate = decodeCourseCandidate(from: candidateData) {
                    courseCandidates.append(candidate)
                }
            }
        }
        
        // Decode chosen course
        var chosenCourse: CourseCandidate?
        if let chosenData = data["chosenCourse"] as? [String: Any] {
            chosenCourse = decodeCourseCandidate(from: chosenData)
        }
        
        // Decode tee time candidates
        var teeTimeCandidates: [Date] = []
        if let timesData = data["teeTimeCandidates"] as? [Timestamp] {
            teeTimeCandidates = timesData.map { $0.dateValue() }
        }
        
        // Decode chosen tee time
        var chosenTeeTime: Date?
        if let chosenTimestamp = data["chosenTeeTime"] as? Timestamp {
            chosenTeeTime = chosenTimestamp.dateValue()
        }
        
        // Decode requirements
        var requirements: RoundRequirements?
        if let reqData = data["requirements"] as? [String: Any] {
            requirements = decodeRequirements(from: reqData)
        }
        
        // Decode price
        var price: RoundPrice?
        if let priceData = data["price"] as? [String: Any] {
            price = decodePrice(from: priceData)
        }
        
        // Decode price tier
        var priceTier: PriceTier?
        if let tierRaw = data["priceTier"] as? String {
            priceTier = PriceTier(rawValue: tierRaw)
        }
        
        // Decode description
        let description = data["description"] as? String
        
        // Decode denormalized query fields
        let cityKey = data["cityKey"] as? String
        var startTime: Date?
        if let startTimestamp = data["startTime"] as? Timestamp {
            startTime = startTimestamp.dateValue()
        }
        let courseLat = data["courseLat"] as? Double
        let courseLng = data["courseLng"] as? Double
        
        // Decode geo data for geohash-based search
        var geo: RoundGeo?
        if let geoData = data["geo"] as? [String: Any],
           let lat = geoData["lat"] as? Double,
           let lng = geoData["lng"] as? Double,
           let geohash = geoData["geohash"] as? String {
            geo = RoundGeo(lat: lat, lng: lng, geohash: geohash)
        }
        
        let maxPlayers = data["maxPlayers"] as? Int ?? 4
        let acceptedCount = data["acceptedCount"] as? Int ?? 1
        let requestCount = data["requestCount"] as? Int ?? 0
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return Round(
            id: id,
            hostUid: hostUid,
            title: title,
            visibility: visibility,
            joinPolicy: joinPolicy,
            cityKey: cityKey,
            startTime: startTime,
            geo: geo,
            courseLat: courseLat,
            courseLng: courseLng,
            courseCandidates: courseCandidates,
            chosenCourse: chosenCourse,
            teeTimeCandidates: teeTimeCandidates,
            chosenTeeTime: chosenTeeTime,
            requirements: requirements,
            price: price,
            priceTier: priceTier,
            description: description,
            maxPlayers: maxPlayers,
            acceptedCount: acceptedCount,
            requestCount: requestCount,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func decodeCourseCandidate(from data: [String: Any]) -> CourseCandidate? {
        guard let name = data["name"] as? String,
              let cityLabel = data["cityLabel"] as? String,
              let geoPoint = data["location"] as? GeoPoint else {
            return nil
        }
        
        return CourseCandidate(
            name: name,
            cityLabel: cityLabel,
            location: GeoLocation(
                latitude: geoPoint.latitude,
                longitude: geoPoint.longitude
            )
        )
    }
    
    private func decodeRequirements(from data: [String: Any]) -> RoundRequirements {
        var genderAllowed: [Gender]?
        if let genderRaws = data["genderAllowed"] as? [String] {
            genderAllowed = genderRaws.compactMap { Gender(rawValue: $0) }
        }
        
        var skillLevelsAllowed: [SkillLevel]?
        if let skillRaws = data["skillLevelsAllowed"] as? [String] {
            skillLevelsAllowed = skillRaws.compactMap { SkillLevel(rawValue: $0) }
        }
        
        return RoundRequirements(
            genderAllowed: genderAllowed,
            minAge: data["minAge"] as? Int,
            maxAge: data["maxAge"] as? Int,
            skillLevelsAllowed: skillLevelsAllowed,
            minAvgScore: data["minAvgScore"] as? Int,
            maxAvgScore: data["maxAvgScore"] as? Int,
            maxDistanceMiles: data["maxDistanceMiles"] as? Int
        )
    }
    
    private func decodePrice(from data: [String: Any]) -> RoundPrice? {
        guard let typeRaw = data["type"] as? String,
              let type = PriceType(rawValue: typeRaw) else {
            return nil
        }
        
        return RoundPrice(
            type: type,
            amount: data["amount"] as? Int,
            min: data["min"] as? Int,
            max: data["max"] as? Int,
            currency: data["currency"] as? String ?? "USD",
            note: data["note"] as? String ?? data["notes"] as? String  // Support both for backward compat
        )
    }
    
    private func decodeMember(from data: [String: Any], id: String) throws -> RoundMember {
        guard let uid = data["uid"] as? String,
              let roleRaw = data["role"] as? String,
              let role = MemberRole(rawValue: roleRaw),
              let statusRaw = data["status"] as? String,
              let status = MemberStatus(rawValue: statusRaw) else {
            throw RoundsRepositoryError.decodingFailed
        }
        
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return RoundMember(
            id: id,
            uid: uid,
            role: role,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Repository Errors

enum RoundsRepositoryError: LocalizedError {
    case notAuthenticated
    case permissionDenied
    case invalidRound
    case roundFull
    case alreadyMember
    case notMember
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .invalidRound:
            return "Invalid round data."
        case .roundFull:
            return "This round is already full."
        case .alreadyMember:
            return "You're already a member of this round."
        case .notMember:
            return "You're not a member of this round."
        case .decodingFailed:
            return "Failed to read round data."
        }
    }
}

