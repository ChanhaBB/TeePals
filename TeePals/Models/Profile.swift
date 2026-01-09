import Foundation
import FirebaseFirestore

struct Profile: Codable, Identifiable {
    @DocumentID var id: String?
    let homeCityLabel: String
    let homeLocation: GeoPoint
    let locationSource: LocationSource
    let ageBucket: AgeBucket
    var avgScore18: Int?
    var skillLevel: SkillLevel?
    let updatedAt: Date
    
    init(
        id: String? = nil,
        homeCityLabel: String,
        homeLocation: GeoPoint,
        locationSource: LocationSource,
        ageBucket: AgeBucket,
        avgScore18: Int? = nil,
        skillLevel: SkillLevel? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.homeCityLabel = homeCityLabel
        self.homeLocation = homeLocation
        self.locationSource = locationSource
        self.ageBucket = ageBucket
        self.avgScore18 = avgScore18
        self.skillLevel = skillLevel
        self.updatedAt = updatedAt
    }
}

enum LocationSource: String, Codable {
    case gps
    case search
}

enum AgeBucket: String, Codable, CaseIterable {
    case age18to24 = "18-24"
    case age25to34 = "25-34"
    case age35to44 = "35-44"
    case age45plus = "45+"
    
    var displayText: String {
        rawValue
    }
}

enum SkillLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    
    var displayText: String {
        rawValue.capitalized
    }
}

