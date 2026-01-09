import Foundation

struct PublicProfile: Codable, Identifiable {
    var id: String?
    
    let nickname: String
    var photoUrl: String?
    var gender: Gender?
    var occupation: String?
    var bio: String?
    
    let primaryCityLabel: String
    let primaryLocation: GeoLocation
    
    var avgScore18: Int?
    var experienceYears: Int?
    var playsPerMonth: Int?
    var skillLevel: SkillLevel?
    var ageDecade: AgeDecade?
    
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        nickname: String,
        photoUrl: String? = nil,
        gender: Gender? = nil,
        occupation: String? = nil,
        bio: String? = nil,
        primaryCityLabel: String,
        primaryLocation: GeoLocation,
        avgScore18: Int? = nil,
        experienceYears: Int? = nil,
        playsPerMonth: Int? = nil,
        skillLevel: SkillLevel? = nil,
        ageDecade: AgeDecade? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.nickname = nickname
        self.photoUrl = photoUrl
        self.gender = gender
        self.occupation = occupation
        self.bio = bio
        self.primaryCityLabel = primaryCityLabel
        self.primaryLocation = primaryLocation
        self.avgScore18 = avgScore18
        self.experienceYears = experienceYears
        self.playsPerMonth = playsPerMonth
        self.skillLevel = skillLevel
        self.ageDecade = ageDecade
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Gender

enum Gender: String, Codable, CaseIterable {
    case male
    case female
    case nonbinary
    case preferNot = "prefer_not"
    
    var displayText: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .nonbinary: return "Non-binary"
        case .preferNot: return "Prefer not to say"
        }
    }
}

// MARK: - Age Decade

enum AgeDecade: String, Codable, CaseIterable {
    case teens = "teens"
    case twenties = "20s"
    case thirties = "30s"
    case forties = "40s"
    case fifties = "50s"
    case sixties = "60s"
    case seventiesPlus = "70s+"
    
    var displayText: String {
        rawValue.capitalized
    }
}

// MARK: - Skill Level

enum SkillLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    
    var displayText: String {
        rawValue.capitalized
    }
}

// MARK: - GeoLocation (Codable wrapper for coordinates)

struct GeoLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

