import Foundation

struct PublicProfile: Codable, Identifiable {
    var id: String?
    
    let nickname: String
    var photoUrls: [String]  // 0-5 photos; Tier 2 requires >= 1
    var gender: Gender?
    var occupation: String?
    var bio: String?
    
    let primaryCityLabel: String
    let primaryLocation: GeoLocation
    
    var avgScore: Int?           // 60-120 in increments of 10
    var experienceLevel: ExperienceLevel?
    var playsPerMonth: Int?
    var skillLevel: SkillLevel?  // Required for Tier 2
    var birthYear: Int?          // Birth year for age calculation (keeps exact date private)
    var ageDecade: AgeDecade?    // Deprecated: use birthYear instead

    // Social media
    var instagramUsername: String?

    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        nickname: String,
        photoUrls: [String] = [],
        gender: Gender? = nil,
        occupation: String? = nil,
        bio: String? = nil,
        primaryCityLabel: String,
        primaryLocation: GeoLocation,
        avgScore: Int? = nil,
        experienceLevel: ExperienceLevel? = nil,
        playsPerMonth: Int? = nil,
        skillLevel: SkillLevel? = nil,
        birthYear: Int? = nil,
        ageDecade: AgeDecade? = nil,
        instagramUsername: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.nickname = nickname
        self.photoUrls = photoUrls
        self.gender = gender
        self.occupation = occupation
        self.bio = bio
        self.primaryCityLabel = primaryCityLabel
        self.primaryLocation = primaryLocation
        self.avgScore = avgScore
        self.experienceLevel = experienceLevel
        self.playsPerMonth = playsPerMonth
        self.skillLevel = skillLevel
        self.birthYear = birthYear
        self.ageDecade = ageDecade
        self.instagramUsername = instagramUsername
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Whether this profile meets Tier 2 requirements (has at least 1 photo)
    var isTier2Complete: Bool {
        !photoUrls.isEmpty
    }
    
    /// Calculated age from birth year (approximate, within 1 year)
    var age: Int? {
        guard let birthYear = birthYear else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - birthYear
    }
    
    /// Normalized city key for Firestore queries
    /// e.g., "San Jose, CA" -> "san_jose_ca"
    var primaryCityKey: String {
        primaryCityLabel
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
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
    case expert
    
    var displayText: String {
        rawValue.capitalized
    }
}

// MARK: - Experience Level

enum ExperienceLevel: String, Codable, CaseIterable {
    case lessThanOne = "less_than_1"
    case oneToThree = "1_to_3"
    case fourToSix = "4_to_6"
    case sevenToTen = "7_to_10"
    case moreThanTen = "more_than_10"
    
    var displayText: String {
        switch self {
        case .lessThanOne: return "< 1 year"
        case .oneToThree: return "1-3 years"
        case .fourToSix: return "4-6 years"
        case .sevenToTen: return "7-10 years"
        case .moreThanTen: return "> 10 years"
        }
    }
}

// MARK: - Avg Score Options

enum AvgScoreOption: Int, CaseIterable, Identifiable {
    case sixty = 60
    case seventy = 70
    case eighty = 80
    case ninety = 90
    case hundred = 100
    case oneHundredTen = 110
    case oneHundredTwenty = 120
    
    var id: Int { rawValue }
    
    var displayText: String {
        "\(rawValue)+"
    }
}

// MARK: - GeoLocation

struct GeoLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
