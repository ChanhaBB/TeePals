import Foundation

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

        // Tier 2 requires at least 1 photo
        if publicProfile?.photoUrls.isEmpty != false {
            missing.append(.profilePhoto)
        }

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
