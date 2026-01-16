import Foundation
import FirebaseFirestore

/// Shared decoder for Round documents from Firestore.
/// Used by multiple services to avoid code duplication.
final class FirestoreRoundDecoder {
    
    func decode(from data: [String: Any], id: String) throws -> Round {
        guard let hostUid = data["hostUid"] as? String,
              let title = data["title"] as? String,
              let visibilityRaw = data["visibility"] as? String,
              let visibility = RoundVisibility(rawValue: visibilityRaw),
              let joinPolicyRaw = data["joinPolicy"] as? String,
              let joinPolicy = JoinPolicy(rawValue: joinPolicyRaw),
              let statusRaw = data["status"] as? String,
              let status = RoundStatus(rawValue: statusRaw) else {
            throw RoundDecodingError.missingRequiredFields
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

// MARK: - Error

enum RoundDecodingError: LocalizedError {
    case missingRequiredFields
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredFields:
            return "Round document is missing required fields."
        }
    }
}

