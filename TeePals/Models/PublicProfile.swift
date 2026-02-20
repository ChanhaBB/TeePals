import Foundation

struct PublicProfile: Codable, Identifiable {
    var id: String?

    // Name fields (V2: firstName + lastName for trust)
    var firstName: String?  // Required for new signups (Tier 1)
    var lastName: String?   // Required for new signups (Tier 1)
    let nickname: String    // Legacy/backward compatibility (auto-generated from firstName for new users)

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

    // Trust System Fields
    var trustTier: TrustTier
    var tierEarnedAt: Date?

    // Trust Badges
    var hasOnTimeBadge: Bool
    var hasCommunicatorBadge: Bool
    var hasRespectfulBadge: Bool
    var hasTrustedRegularBadge: Bool
    var hasWellMatchedBadge: Bool
    var hasRookieBadge: Bool

    // Stats (last 5 rounds)
    var recentWouldPlayAgainPct: Double
    var recentNoShowCount: Int
    var recentLateCount: Int
    var recentDisrespectCount: Int
    var recentSkillMismatchCount: Int
    var recentCommunicationFlags: Int

    // Lifetime
    var completedRoundsCount: Int
    var lifetimeWouldPlayAgainPct: Double

    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
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
        trustTier: TrustTier = .rookie,
        tierEarnedAt: Date? = nil,
        hasOnTimeBadge: Bool = false,
        hasCommunicatorBadge: Bool = false,
        hasRespectfulBadge: Bool = false,
        hasTrustedRegularBadge: Bool = false,
        hasWellMatchedBadge: Bool = false,
        hasRookieBadge: Bool = true,
        recentWouldPlayAgainPct: Double = 0.0,
        recentNoShowCount: Int = 0,
        recentLateCount: Int = 0,
        recentDisrespectCount: Int = 0,
        recentSkillMismatchCount: Int = 0,
        recentCommunicationFlags: Int = 0,
        completedRoundsCount: Int = 0,
        lifetimeWouldPlayAgainPct: Double = 0.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
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
        self.trustTier = trustTier
        self.tierEarnedAt = tierEarnedAt
        self.hasOnTimeBadge = hasOnTimeBadge
        self.hasCommunicatorBadge = hasCommunicatorBadge
        self.hasRespectfulBadge = hasRespectfulBadge
        self.hasTrustedRegularBadge = hasTrustedRegularBadge
        self.hasWellMatchedBadge = hasWellMatchedBadge
        self.hasRookieBadge = hasRookieBadge
        self.recentWouldPlayAgainPct = recentWouldPlayAgainPct
        self.recentNoShowCount = recentNoShowCount
        self.recentLateCount = recentLateCount
        self.recentDisrespectCount = recentDisrespectCount
        self.recentSkillMismatchCount = recentSkillMismatchCount
        self.recentCommunicationFlags = recentCommunicationFlags
        self.completedRoundsCount = completedRoundsCount
        self.lifetimeWouldPlayAgainPct = lifetimeWouldPlayAgainPct
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Display name: "John D." format (first name + last initial)
    /// Falls back to nickname for legacy profiles
    var displayName: String {
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            let lastInitial = lastName.prefix(1).uppercased()
            return "\(firstName) \(lastInitial)."
        } else if let firstName = firstName, !firstName.isEmpty {
            return firstName
        } else {
            return nickname
        }
    }

    /// Full name: "John Doe" format
    /// Falls back to nickname for legacy profiles
    var fullName: String {
        if let firstName = firstName, let lastName = lastName, !firstName.isEmpty, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if let firstName = firstName, !firstName.isEmpty {
            return firstName
        } else {
            return nickname
        }
    }

    /// Whether this profile meets Tier 2 requirements (has at least 1 photo)
    var isTier2Complete: Bool {
        !photoUrls.isEmpty
    }
    
    /// Calculated age from birth year (approximate, within 1 year)
    /// Note: This is an approximation for other users' profiles
    /// For own profile, use PrivateProfile.age which is accurate
    /// Shows conservative (younger) age since we don't know exact birthday
    var age: Int? {
        guard let birthYear = birthYear else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        // Subtract 1 to be conservative since birthday may not have passed yet
        return max(0, currentYear - birthYear - 1)
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

    /// Trust tier badge display text
    var trustTierBadge: String {
        trustTier.displayName
    }

    /// All earned badges (excluding rookie)
    var earnedBadges: [String] {
        var badges: [String] = []
        if hasTrustedRegularBadge { badges.append("⭐ Trusted Regular") }
        if hasOnTimeBadge { badges.append("🕐 On-Time") }
        if hasRespectfulBadge { badges.append("🤝 Respectful") }
        if hasWellMatchedBadge { badges.append("📊 Well-Matched") }
        if hasCommunicatorBadge { badges.append("💬 Clear Communicator") }
        return badges
    }

    /// Top 2 badges for compact display
    var topBadges: [String] {
        Array(earnedBadges.prefix(2))
    }

    /// Whether to show "would play again" stat (requires 5+ rounds)
    var shouldShowPlayAgainStat: Bool {
        completedRoundsCount >= 5
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
