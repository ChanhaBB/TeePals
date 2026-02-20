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


