import Foundation

/// Segment options for the Rounds tab.
enum RoundsSegment: Int, CaseIterable, Identifiable {
    case nearby
    case activity
    case following
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .nearby: return "Nearby"
        case .activity: return "Activity"
        case .following: return "Following"
        }
    }
}

