import Foundation
import FirebaseFirestore

/// Firestore implementation of RoundsSearchService using geohash-based queries.
/// Implements the search algorithm from GEOHASH_PLAN.md.
final class FirestoreGeoHashRoundsSearchService: RoundsSearchService {
    
    private let db = Firestore.firestore()
    
    // MARK: - Search
    
    func searchRounds(
        filter: RoundsSearchFilter,
        page: RoundsPageCursor?
    ) async throws -> RoundsSearchPage {
        // Route to appropriate search strategy
        if filter.isDiscoveryMode {
            return try await searchRoundsDiscoveryMode(filter: filter, page: page)
        } else {
            return try await searchRoundsGeoMode(filter: filter, page: page)
        }
    }
    
    // MARK: - Geo Mode Search (Location + Radius)
    
    private func searchRoundsGeoMode(
        filter: RoundsSearchFilter,
        page: RoundsPageCursor?
    ) async throws -> RoundsSearchPage {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Validate inputs
        try validateFilter(filter)
        
        // Compute geohash bounds for the search area
        let precision = filter.queryPrecision
        let bounds = GeoHashUtil.queryBounds(
            centerLat: filter.centerLat,
            centerLng: filter.centerLng,
            radiusMeters: filter.radiusMeters,
            precision: precision
        )
        
        #if DEBUG
        print("🔍 GeoSearch: center=(\(filter.centerLat), \(filter.centerLng)), radius=\(filter.radiusMiles)mi, precision=\(precision)")
        print("🔍 GeoSearch: bounds count=\(bounds.count)")
        for (i, bound) in bounds.enumerated() {
            print("   Bound \(i): \(bound.start) to \(bound.end)")
        }
        #endif
        
        guard !bounds.isEmpty else {
            print("⚠️ GeoSearch: No bounds computed!")
            return .empty
        }
        
        // Run queries for each bound and collect candidates
        var candidatesMap: [String: Round] = [:] // Dedupe by ID
        var totalFetched = 0
        var isTruncated = false
        
        for bound in bounds {
            // Check if we've hit the max candidates limit
            if candidatesMap.count >= GeoPrecisionPolicy.maxCandidatesTotal {
                isTruncated = true
                break
            }
            
            let remaining = GeoPrecisionPolicy.maxCandidatesTotal - candidatesMap.count
            let fetchLimit = min(GeoPrecisionPolicy.perBoundLimit, remaining)
            
            let boundResults = try await fetchRoundsForBound(
                bound: bound,
                filter: filter,
                limit: fetchLimit
            )
            
            totalFetched += boundResults.count
            
            for round in boundResults {
                if let id = round.id {
                    candidatesMap[id] = round
                }
            }
        }
        
        // Apply exact distance filter
        var candidates = Array(candidatesMap.values)
        let afterDistance = applyDistanceFilter(
            rounds: &candidates,
            filter: filter
        )
        
        // Apply date window filter (should mostly be server-side, but verify)
        let afterDate = applyDateFilter(
            rounds: &candidates,
            filter: filter
        )
        
        // Apply additional filters
        applyAdditionalFilters(rounds: &candidates, filter: filter)
        
        // Sort deterministically
        sortResults(&candidates)
        
        // Handle pagination
        if let cursor = page {
            candidates = applyPagination(rounds: candidates, cursor: cursor)
        }
        
        // Take page size
        let pageSize = 30
        let hasMore = candidates.count > pageSize
        let pageItems = Array(candidates.prefix(pageSize))
        
        // Build next cursor
        let nextCursor: RoundsPageCursor?
        if hasMore, let lastRound = pageItems.last {
            nextCursor = RoundsPageCursor(from: lastRound)
        } else {
            nextCursor = nil
        }
        
        // Build debug info
        let duration = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        let debug = RoundsSearchDebugInfo(
            boundsQueried: bounds.count,
            candidatesFetched: totalFetched,
            candidatesAfterDistance: afterDistance,
            candidatesAfterDate: afterDate,
            resultsCount: pageItems.count,
            durationMs: duration,
            precision: precision
        )
        
        return RoundsSearchPage(
            items: pageItems,
            nextPageCursor: nextCursor,
            debug: debug,
            isTruncated: isTruncated
        )
    }
    
    // MARK: - Discovery Mode Search (Date-only, Anywhere)
    
    private func searchRoundsDiscoveryMode(
        filter: RoundsSearchFilter,
        page: RoundsPageCursor?
    ) async throws -> RoundsSearchPage {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Validate date window only
        guard filter.startTimeMax > filter.startTimeMin else {
            throw RoundsSearchError.dateWindowInvalid
        }
        
        // Build date-based query (no geo constraints)
        var query: Query = db.collection(FirestoreCollection.rounds)
        
        // Filter by date range
        query = query
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: filter.startTimeMin))
            .whereField("startTime", isLessThan: Timestamp(date: filter.startTimeMax))
        
        // Filter by status
        if let status = filter.status {
            query = query.whereField("status", isEqualTo: status.rawValue)
        }
        
        // Filter by visibility
        if let visibility = filter.visibility {
            query = query.whereField("visibility", isEqualTo: visibility.rawValue)
        } else {
            // Default to public
            query = query.whereField("visibility", isEqualTo: RoundVisibility.public.rawValue)
        }
        
        // Order by startTime (soonest first)
        query = query.order(by: "startTime", descending: false)
        
        // Limit to reasonable batch size
        let fetchLimit = 200
        query = query.limit(to: fetchLimit)
        
        // Apply pagination cursor if present
        if let cursor = page {
            query = query.start(after: [Timestamp(date: cursor.lastStartTime)])
        }
        
        let snapshot = try await query.getDocuments()
        
        var candidates: [Round] = []
        for doc in snapshot.documents {
            if let round = try? decodeRound(from: doc.data(), id: doc.documentID) {
                // Apply excludeFullRounds filter client-side
                if filter.excludeFullRounds && round.isFull {
                    continue
                }
                candidates.append(round)
            }
        }
        
        // Sort deterministically
        sortResults(&candidates)
        
        // Take page size
        let pageSize = 30
        let hasMore = candidates.count > pageSize
        let pageItems = Array(candidates.prefix(pageSize))
        
        // Build next cursor
        let nextCursor: RoundsPageCursor?
        if hasMore, let lastRound = pageItems.last {
            nextCursor = RoundsPageCursor(from: lastRound)
        } else {
            nextCursor = nil
        }
        
        // Build debug info
        let duration = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        let debug = RoundsSearchDebugInfo(
            boundsQueried: 0,  // No geo bounds in discovery mode
            candidatesFetched: snapshot.documents.count,
            candidatesAfterDistance: candidates.count, // No distance filter
            candidatesAfterDate: candidates.count,
            resultsCount: pageItems.count,
            durationMs: duration,
            precision: 0  // No precision in discovery mode
        )
        
        return RoundsSearchPage(
            items: pageItems,
            nextPageCursor: nextCursor,
            debug: debug,
            isTruncated: snapshot.documents.count >= fetchLimit
        )
    }
    
    // MARK: - Validation
    
    private func validateFilter(_ filter: RoundsSearchFilter) throws {
        // Skip geo validation for discovery mode
        if !filter.isDiscoveryMode {
            // Validate coordinates
            guard filter.centerLat >= -90, filter.centerLat <= 90,
                  filter.centerLng >= -180, filter.centerLng <= 180 else {
                throw RoundsSearchError.invalidCoordinates
            }
            
            // Validate radius
            guard filter.radiusMiles <= GeoPrecisionPolicy.maxRadiusMiles else {
                throw RoundsSearchError.radiusTooLarge
            }
        }
        
        // Validate date window
        guard filter.startTimeMax > filter.startTimeMin else {
            throw RoundsSearchError.dateWindowInvalid
        }
        
        let daysBetween = Calendar.current.dateComponents(
            [.day],
            from: filter.startTimeMin,
            to: filter.startTimeMax
        ).day ?? 0
        
        guard daysBetween <= GeoPrecisionPolicy.maxDateWindowDays else {
            throw RoundsSearchError.dateWindowTooLarge
        }
    }
    
    // MARK: - Firestore Query
    
    private func fetchRoundsForBound(
        bound: (start: String, end: String),
        filter: RoundsSearchFilter,
        limit: Int
    ) async throws -> [Round] {
        var query: Query = db.collection(FirestoreCollection.rounds)
        
        // Geohash range query
        query = query
            .order(by: "geo.geohash")
            .whereField("geo.geohash", isGreaterThanOrEqualTo: bound.start)
            .whereField("geo.geohash", isLessThanOrEqualTo: bound.end)
        
        // Note: Firestore doesn't support multiple inequality filters on different fields
        // in the same query. We apply date/status filters client-side after geohash query.
        
        query = query.limit(to: limit)
        
        do {
            let snapshot = try await query.getDocuments()
            
            #if DEBUG
            print("🔍 Bound query [\(bound.start)...\(bound.end)]: \(snapshot.documents.count) docs")
            #endif
            
            var rounds: [Round] = []
            for doc in snapshot.documents {
                if let round = try? decodeRound(from: doc.data(), id: doc.documentID) {
                    rounds.append(round)
                    #if DEBUG
                    if let geo = round.geo {
                        print("   ✅ Round \(round.id ?? "?"): geohash=\(geo.geohash)")
                    } else {
                        print("   ⚠️ Round \(round.id ?? "?"): NO GEO DATA")
                    }
                    #endif
                } else {
                    #if DEBUG
                    print("   ❌ Failed to decode doc: \(doc.documentID)")
                    #endif
                }
            }
            
            return rounds
        } catch {
            #if DEBUG
            print("❌ Firestore query error: \(error)")
            print("   This may indicate a missing index. Check Firestore console.")
            #endif
            throw error
        }
    }
    
    // MARK: - Filters
    
    private func applyDistanceFilter(
        rounds: inout [Round],
        filter: RoundsSearchFilter
    ) -> Int {
        rounds = rounds.filter { round in
            guard let geo = round.geo else {
                // No geo data - exclude from results
                return false
            }
            
            let distance = DistanceUtil.haversineMiles(
                lat1: filter.centerLat, lng1: filter.centerLng,
                lat2: geo.lat, lng2: geo.lng
            )
            
            return distance <= filter.radiusMiles
        }
        
        // Compute and store distance for sorting
        for i in rounds.indices {
            if let geo = rounds[i].geo {
                rounds[i].distanceMiles = DistanceUtil.haversineMiles(
                    lat1: filter.centerLat, lng1: filter.centerLng,
                    lat2: geo.lat, lng2: geo.lng
                )
            }
        }
        
        return rounds.count
    }
    
    private func applyDateFilter(
        rounds: inout [Round],
        filter: RoundsSearchFilter
    ) -> Int {
        rounds = rounds.filter { round in
            guard let startTime = round.startTime ?? round.chosenTeeTime else {
                return false
            }
            return startTime >= filter.startTimeMin && startTime < filter.startTimeMax
        }
        return rounds.count
    }
    
    private func applyAdditionalFilters(
        rounds: inout [Round],
        filter: RoundsSearchFilter
    ) {
        // Status filter
        if let status = filter.status {
            rounds = rounds.filter { $0.status == status }
        }
        
        // Visibility filter
        if let visibility = filter.visibility {
            rounds = rounds.filter { $0.visibility == visibility }
        } else {
            // Default to public
            rounds = rounds.filter { $0.visibility == .public }
        }
        
        // Exclude full rounds
        if filter.excludeFullRounds {
            rounds = rounds.filter { !$0.isFull }
        }
        
        // Host filter
        if let hostUid = filter.hostUid {
            rounds = rounds.filter { $0.hostUid == hostUid }
        }
    }
    
    // MARK: - Sorting
    
    private func sortResults(_ rounds: inout [Round]) {
        // Sort by startTime ascending, then by ID for tiebreaker
        rounds.sort { lhs, rhs in
            let lhsTime = lhs.startTime ?? lhs.chosenTeeTime ?? .distantFuture
            let rhsTime = rhs.startTime ?? rhs.chosenTeeTime ?? .distantFuture
            
            if lhsTime != rhsTime {
                return lhsTime < rhsTime
            }
            
            // Tiebreaker by ID
            return (lhs.id ?? "") < (rhs.id ?? "")
        }
    }
    
    // MARK: - Pagination
    
    private func applyPagination(rounds: [Round], cursor: RoundsPageCursor) -> [Round] {
        // Skip rounds until we find one after the cursor
        var foundCursor = false
        var result: [Round] = []
        
        for round in rounds {
            if foundCursor {
                result.append(round)
                continue
            }
            
            let roundTime = round.startTime ?? round.chosenTeeTime ?? .distantFuture
            let roundId = round.id ?? ""
            
            // Check if this round is after the cursor
            if roundTime > cursor.lastStartTime ||
               (roundTime == cursor.lastStartTime && roundId > cursor.lastRoundId) {
                foundCursor = true
                result.append(round)
            }
        }
        
        return result
    }
}

// MARK: - Decoding

extension FirestoreGeoHashRoundsSearchService {
    
    private func decodeRound(from data: [String: Any], id: String) throws -> Round {
        guard let hostUid = data["hostUid"] as? String,
              let title = data["title"] as? String,
              let visibilityRaw = data["visibility"] as? String,
              let visibility = RoundVisibility(rawValue: visibilityRaw),
              let joinPolicyRaw = data["joinPolicy"] as? String,
              let joinPolicy = JoinPolicy(rawValue: joinPolicyRaw),
              let statusRaw = data["status"] as? String,
              let status = RoundStatus(rawValue: statusRaw) else {
            throw RoundsSearchError.firestoreError(underlying: NSError(
                domain: "RoundsSearch",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing required fields"]
            ))
        }
        
        // Decode geo data
        var geo: RoundGeo?
        if let geoData = data["geo"] as? [String: Any],
           let lat = geoData["lat"] as? Double,
           let lng = geoData["lng"] as? Double,
           let geohash = geoData["geohash"] as? String {
            geo = RoundGeo(lat: lat, lng: lng, geohash: geohash)
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
            note: data["note"] as? String ?? data["notes"] as? String
        )
    }
}

