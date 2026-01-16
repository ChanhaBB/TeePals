import Foundation

/// Profile completion tiers as defined in design doc v2.
/// - incomplete: Missing Tier 1 requirements (cannot use app)
/// - tier1: Has Tier 1 requirements, can browse but not engage
/// - tier2: Fully complete, can participate in all actions
enum ProfileCompletionLevel: Int, Comparable {
    case incomplete = 0
    case tier1 = 1
    case tier2 = 2
    
    static func < (lhs: ProfileCompletionLevel, rhs: ProfileCompletionLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Individual requirements that may be missing from a profile.
enum ProfileRequirement: String, CaseIterable {
    // Tier 1 requirements
    case nickname
    case primaryLocation
    case birthDate
    case gender
    
    // Tier 2 requirements
    case profilePhoto
    
    var displayName: String {
        switch self {
        case .nickname: return "Nickname"
        case .primaryLocation: return "Location"
        case .birthDate: return "Birth date"
        case .gender: return "Gender"
        case .profilePhoto: return "Profile photo"
        }
    }
    
    var tier: ProfileCompletionLevel {
        switch self {
        case .nickname, .primaryLocation, .birthDate, .gender:
            return .tier1
        case .profilePhoto:
            return .tier2
        }
    }
    
    var systemImage: String {
        switch self {
        case .nickname: return "person.fill"
        case .primaryLocation: return "location.fill"
        case .birthDate: return "calendar"
        case .gender: return "person.2.fill"
        case .profilePhoto: return "camera.fill"
        }
    }
}

/// Result of evaluating a user's profile completion status.
struct ProfileCompletionStatus {
    let level: ProfileCompletionLevel
    let missingRequirements: [ProfileRequirement]
    
    var isComplete: Bool {
        level == .tier2
    }
    
    var canBrowse: Bool {
        level >= .tier1
    }
    
    var canEngage: Bool {
        level >= .tier2
    }
    
    /// Returns requirements missing for a specific tier.
    func missingFor(tier: ProfileCompletionLevel) -> [ProfileRequirement] {
        missingRequirements.filter { $0.tier.rawValue <= tier.rawValue }
    }
    
    /// Human-readable summary of what's missing.
    var missingSummary: String {
        guard !missingRequirements.isEmpty else { return "" }
        let names = missingRequirements.map { $0.displayName.lowercased() }
        if names.count == 1 {
            return names[0]
        } else if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        } else {
            return names.dropLast().joined(separator: ", ") + ", and " + names.last!
        }
    }
}

/// Evaluates profile completion status from public and private profile data.
struct ProfileCompletionEvaluator {
    
    /// Evaluates the completion level and missing requirements.
    /// - Parameters:
    ///   - publicProfile: The user's public profile (nil if not created)
    ///   - privateProfile: The user's private profile (nil if not created)
    /// - Returns: The completion status with level and missing requirements
    static func evaluate(
        publicProfile: PublicProfile?,
        privateProfile: PrivateProfile?
    ) -> ProfileCompletionStatus {
        var missing: [ProfileRequirement] = []
        
        // Check Tier 1 requirements
        if publicProfile == nil || publicProfile!.nickname.trimmingCharacters(in: .whitespaces).isEmpty {
            missing.append(.nickname)
        }
        
        if publicProfile?.primaryCityLabel.isEmpty != false {
            missing.append(.primaryLocation)
        }
        
        if privateProfile?.birthDate.isEmpty != false {
            missing.append(.birthDate)
        }
        
        // Gender: must be explicitly set (nil = missing, any value including preferNot = OK)
        if publicProfile?.gender == nil {
            missing.append(.gender)
        }
        
        // Check Tier 2 requirements
        // Tier 2 requires at least 1 photo (skill level is optional)
        if publicProfile?.photoUrls.isEmpty != false {
            missing.append(.profilePhoto)
        }
        
        // Determine level based on what's missing
        let hasTier1Missing = missing.contains { $0.tier == .tier1 }
        let hasTier2Missing = missing.contains { $0.tier == .tier2 }
        
        let level: ProfileCompletionLevel
        if hasTier1Missing {
            level = .incomplete
        } else if hasTier2Missing {
            level = .tier1
        } else {
            level = .tier2
        }
        
        return ProfileCompletionStatus(level: level, missingRequirements: missing)
    }
    
    /// Convenience method when you only have a public profile.
    static func evaluate(publicProfile: PublicProfile?) -> ProfileCompletionStatus {
        evaluate(publicProfile: publicProfile, privateProfile: nil)
    }
}

