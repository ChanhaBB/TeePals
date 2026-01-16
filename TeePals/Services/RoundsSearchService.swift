import Foundation

// MARK: - RoundsSearchService Protocol

/// Protocol for geo-based rounds search.
/// Abstraction allows swapping Firestore implementation for other backends later.
protocol RoundsSearchService {
    
    /// Search rounds within a geographic radius and date window.
    /// - Parameters:
    ///   - filter: Search filter containing center point, radius, date range
    ///   - page: Optional page cursor for pagination
    /// - Returns: Search results page with rounds and pagination info
    func searchRounds(
        filter: RoundsSearchFilter,
        page: RoundsPageCursor?
    ) async throws -> RoundsSearchPage
}

// MARK: - Search Filter

/// Filter parameters for geo-based rounds search.
struct RoundsSearchFilter: Equatable {
    
    // MARK: - Location (ignored in discovery mode)
    
    /// Center point latitude for geo search.
    let centerLat: Double
    
    /// Center point longitude for geo search.
    let centerLng: Double
    
    /// Search radius in miles.
    let radiusMiles: Double
    
    // MARK: - Required: Date Window
    
    /// Start of date window (inclusive).
    let startTimeMin: Date
    
    /// End of date window (exclusive).
    let startTimeMax: Date
    
    // MARK: - Mode
    
    /// When true, ignores location/radius and searches by date only.
    let isDiscoveryMode: Bool
    
    // MARK: - Optional Filters
    
    /// Filter by round status (default: open).
    var status: RoundStatus?
    
    /// Filter by visibility (default: nil = all).
    var visibility: RoundVisibility?
    
    /// Exclude full rounds from results.
    var excludeFullRounds: Bool
    
    /// Specific host UID filter (for "My Rounds" queries).
    var hostUid: String?
    
    // MARK: - Initializer
    
    init(
        centerLat: Double,
        centerLng: Double,
        radiusMiles: Double = GeoPrecisionPolicy.defaultRadiusMiles,
        startTimeMin: Date,
        startTimeMax: Date,
        status: RoundStatus? = .open,
        visibility: RoundVisibility? = nil,
        excludeFullRounds: Bool = true,
        hostUid: String? = nil,
        isDiscoveryMode: Bool = false
    ) {
        self.centerLat = centerLat
        self.centerLng = centerLng
        self.radiusMiles = radiusMiles
        self.startTimeMin = startTimeMin
        self.startTimeMax = startTimeMax
        self.isDiscoveryMode = isDiscoveryMode
        self.status = status
        self.visibility = visibility
        self.excludeFullRounds = excludeFullRounds
        self.hostUid = hostUid
    }
    
    // MARK: - Convenience Initializers
    
    /// Create filter from GeoLocation and DateRangeOption.
    init(
        center: GeoLocation,
        radiusMiles: Double = GeoPrecisionPolicy.defaultRadiusMiles,
        dateRange: DateRangeOption = .next30,
        status: RoundStatus? = .open,
        visibility: RoundVisibility? = nil,
        excludeFullRounds: Bool = true,
        hostUid: String? = nil,
        isDiscoveryMode: Bool = false
    ) {
        self.centerLat = center.latitude
        self.centerLng = center.longitude
        self.radiusMiles = radiusMiles
        self.startTimeMin = dateRange.startDate
        self.startTimeMax = dateRange.endDate
        self.isDiscoveryMode = isDiscoveryMode
        self.status = status
        self.visibility = visibility
        self.excludeFullRounds = excludeFullRounds
        self.hostUid = hostUid
    }
    
    // MARK: - Computed Properties
    
    /// Center as GeoLocation.
    var center: GeoLocation {
        GeoLocation(latitude: centerLat, longitude: centerLng)
    }
    
    /// Radius in meters (for geohash calculations).
    var radiusMeters: Double {
        DistanceUtil.milesToMeters(radiusMiles)
    }
    
    /// Recommended geohash precision for this radius.
    var queryPrecision: Int {
        GeoPrecisionPolicy.queryPrecision(forRadiusMiles: radiusMiles)
    }
}

// MARK: - Search Results

/// Paginated search results.
struct RoundsSearchPage {
    
    /// Rounds matching the search criteria.
    let items: [Round]
    
    /// Cursor for fetching the next page, nil if no more results.
    let nextPageCursor: RoundsPageCursor?
    
    /// Debug information (only populated in debug builds).
    let debug: RoundsSearchDebugInfo?
    
    /// True if results were truncated due to hitting max candidates limit.
    let isTruncated: Bool
    
    init(
        items: [Round],
        nextPageCursor: RoundsPageCursor? = nil,
        debug: RoundsSearchDebugInfo? = nil,
        isTruncated: Bool = false
    ) {
        self.items = items
        self.nextPageCursor = nextPageCursor
        self.debug = debug
        self.isTruncated = isTruncated
    }
    
    /// Empty page (no results).
    static let empty = RoundsSearchPage(items: [])
}

// MARK: - Pagination

/// Cursor for paginating through search results.
struct RoundsPageCursor: Equatable {
    
    /// Start time of the last seen round.
    let lastStartTime: Date
    
    /// ID of the last seen round (for tiebreaker).
    let lastRoundId: String
    
    init(lastStartTime: Date, lastRoundId: String) {
        self.lastStartTime = lastStartTime
        self.lastRoundId = lastRoundId
    }
    
    /// Create cursor from a Round.
    init?(from round: Round) {
        guard let id = round.id, let startTime = round.startTime else { return nil }
        self.lastStartTime = startTime
        self.lastRoundId = id
    }
}

// MARK: - Debug Info

/// Debug information for search operations (dev builds only).
struct RoundsSearchDebugInfo {
    
    /// Number of geohash bounds queried.
    let boundsQueried: Int
    
    /// Total candidates fetched before filtering.
    let candidatesFetched: Int
    
    /// Candidates after exact distance filter.
    let candidatesAfterDistance: Int
    
    /// Candidates after date filter.
    let candidatesAfterDate: Int
    
    /// Final results count.
    let resultsCount: Int
    
    /// Time taken for search (milliseconds).
    let durationMs: Int
    
    /// Geohash precision used.
    let precision: Int
}

// MARK: - Search Errors

enum RoundsSearchError: LocalizedError {
    case invalidCoordinates
    case radiusTooLarge
    case dateWindowTooLarge
    case dateWindowInvalid
    case maxCandidatesExceeded
    case firestoreError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            return "Invalid coordinates provided for search."
        case .radiusTooLarge:
            return "Search radius is too large. Please narrow your search."
        case .dateWindowTooLarge:
            return "Date range is too large. Please select a shorter range."
        case .dateWindowInvalid:
            return "Invalid date range. End date must be after start date."
        case .maxCandidatesExceeded:
            return "Too many results found. Please narrow your search criteria."
        case .firestoreError(let underlying):
            return "Database error: \(underlying.localizedDescription)"
        }
    }
}

