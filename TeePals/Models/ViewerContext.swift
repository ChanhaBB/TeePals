import Foundation

/// Viewer preferences and context for feed personalization
struct ViewerContext {
    let userId: String
    let cityId: String?
    let homeCourseId: String?
    let interests: [String]  // Tags user has engaged with

    init(
        userId: String,
        cityId: String? = nil,
        homeCourseId: String? = nil,
        interests: [String] = []
    ) {
        self.userId = userId
        self.cityId = cityId
        self.homeCourseId = homeCourseId
        self.interests = interests
    }

    /// Create ViewerContext from PublicProfile
    static func from(userId: String, profile: PublicProfile?) -> ViewerContext {
        return ViewerContext(
            userId: userId,
            cityId: profile?.primaryCityKey,
            homeCourseId: nil,  // TODO: Add homeCourseId to profile later
            interests: []       // TODO: Track user interests later
        )
    }
}
