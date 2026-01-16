import Foundation

/// Round model aligned with v2 design doc.
/// Represents a golf round that users can create, browse, and join.
struct Round: Codable, Identifiable, Hashable {
    
    // Compare by id AND updatedAt so SwiftUI re-renders when data changes
    static func == (lhs: Round, rhs: Round) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    var id: String?
    let hostUid: String
    var title: String
    var visibility: RoundVisibility
    var joinPolicy: JoinPolicy
    
    // Denormalized fields for efficient Firestore queries
    var cityKey: String?           // Normalized city key, e.g., "san_jose_ca"
    var startTime: Date?           // First/primary tee time for date range queries
    var geo: RoundGeo?             // Geo data for geohash-based search
    
    // Legacy fields (kept for backward compatibility during migration)
    var courseLat: Double?         // Deprecated: use geo.lat
    var courseLng: Double?         // Deprecated: use geo.lng
    
    // Course options (v2: multiple candidates, one chosen)
    var courseCandidates: [CourseCandidate]
    var chosenCourse: CourseCandidate?
    
    // Tee time options (v2: multiple candidates, one chosen)
    var teeTimeCandidates: [Date]
    var chosenTeeTime: Date?
    
    // Requirements (optional filters for who can join)
    var requirements: RoundRequirements?
    
    // Price info (informational only, non-transactional)
    var price: RoundPrice?
    var priceTier: PriceTier?
    
    // Optional description from host
    var description: String?
    
    var maxPlayers: Int
    var acceptedCount: Int
    var requestCount: Int
    var status: RoundStatus
    let createdAt: Date
    var updatedAt: Date
    
    // Computed property for client-side distance (not stored)
    var distanceMiles: Double?
    
    init(
        id: String? = nil,
        hostUid: String,
        title: String,
        visibility: RoundVisibility = .public,
        joinPolicy: JoinPolicy = .request,
        cityKey: String? = nil,
        startTime: Date? = nil,
        geo: RoundGeo? = nil,
        courseLat: Double? = nil,
        courseLng: Double? = nil,
        courseCandidates: [CourseCandidate] = [],
        chosenCourse: CourseCandidate? = nil,
        teeTimeCandidates: [Date] = [],
        chosenTeeTime: Date? = nil,
        requirements: RoundRequirements? = nil,
        price: RoundPrice? = nil,
        priceTier: PriceTier? = nil,
        description: String? = nil,
        maxPlayers: Int = 4,
        acceptedCount: Int = 1,
        requestCount: Int = 0,
        status: RoundStatus = .open,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.hostUid = hostUid
        self.title = title
        self.visibility = visibility
        self.joinPolicy = joinPolicy
        self.cityKey = cityKey
        self.startTime = startTime
        self.geo = geo
        self.courseLat = courseLat
        self.courseLng = courseLng
        self.courseCandidates = courseCandidates
        self.chosenCourse = chosenCourse
        self.teeTimeCandidates = teeTimeCandidates
        self.chosenTeeTime = chosenTeeTime
        self.requirements = requirements
        self.price = price
        self.priceTier = priceTier
        self.description = description
        self.maxPlayers = maxPlayers
        self.acceptedCount = acceptedCount
        self.requestCount = requestCount
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    
    var isFull: Bool {
        acceptedCount >= maxPlayers
    }
    
    var spotsRemaining: Int {
        max(0, maxPlayers - acceptedCount)
    }
    
    /// Display course name (chosen or first candidate)
    var displayCourseName: String {
        chosenCourse?.name ?? courseCandidates.first?.name ?? "TBD"
    }
    
    /// Display city label (chosen or first candidate)
    var displayCityLabel: String {
        chosenCourse?.cityLabel ?? courseCandidates.first?.cityLabel ?? ""
    }
    
    /// Display tee time (chosen or first candidate)
    var displayTeeTime: Date? {
        chosenTeeTime ?? teeTimeCandidates.first
    }
    
    /// Display location for distance calculation
    var displayLocation: GeoLocation? {
        // Prefer geo struct, then legacy courseLat/lng, then course candidates
        if let geo = geo {
            return GeoLocation(latitude: geo.lat, longitude: geo.lng)
        }
        if let lat = courseLat, let lng = courseLng {
            return GeoLocation(latitude: lat, longitude: lng)
        }
        return chosenCourse?.location ?? courseCandidates.first?.location
    }
    
    /// Display title: course name, stripping "Round at " prefix if present
    var displayTitle: String {
        let title = self.title
        if title.hasPrefix("Round at ") {
            return String(title.dropFirst("Round at ".count))
        }
        if !title.isEmpty && title != "Golf Round" {
            return title
        }
        return displayCourseName
    }
    
    /// Display date/time formatted string
    var displayDateTime: String? {
        guard let teeTime = displayTeeTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d · h:mm a"
        return formatter.string(from: teeTime)
    }
    
    /// Display location string (city, state)
    var displayLocationString: String? {
        let cityLabel = displayCityLabel
        return cityLabel.isEmpty ? nil : cityLabel
    }
    
    /// Generate a normalized city key from city label
    /// e.g., "San Jose, CA" -> "san_jose_ca"
    static func generateCityKey(from cityLabel: String) -> String {
        cityLabel
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}

// MARK: - Round Geo

/// Geographic data for geohash-based search.
/// Stored at `geo.lat`, `geo.lng`, `geo.geohash` in Firestore.
struct RoundGeo: Codable, Equatable {
    let lat: Double
    let lng: Double
    let geohash: String
    
    init(lat: Double, lng: Double, geohash: String) {
        self.lat = lat
        self.lng = lng
        self.geohash = geohash
    }
    
    /// Create RoundGeo from coordinates, computing geohash automatically.
    /// - Parameters:
    ///   - latitude: Latitude (-90 to 90)
    ///   - longitude: Longitude (-180 to 180)
    ///   - precision: Geohash precision (default: 9 per storage policy)
    init(latitude: Double, longitude: Double, precision: Int = GeoPrecisionPolicy.storagePrecision) {
        self.lat = latitude
        self.lng = longitude
        self.geohash = GeoHashUtil.encode(latitude: latitude, longitude: longitude, precision: precision)
    }
    
    /// Create RoundGeo from a GeoLocation, computing geohash automatically.
    init(location: GeoLocation, precision: Int = GeoPrecisionPolicy.storagePrecision) {
        self.lat = location.latitude
        self.lng = location.longitude
        self.geohash = GeoHashUtil.encode(latitude: location.latitude, longitude: location.longitude, precision: precision)
    }
}

// MARK: - Course Candidate

struct CourseCandidate: Codable, Equatable, Identifiable {
    var id: String { name + cityLabel }
    let name: String
    let cityLabel: String
    let location: GeoLocation
    
    init(name: String, cityLabel: String, location: GeoLocation) {
        self.name = name
        self.cityLabel = cityLabel
        self.location = location
    }
}

// MARK: - Round Requirements

struct RoundRequirements: Codable {
    var genderAllowed: [Gender]?
    var minAge: Int?
    var maxAge: Int?
    var skillLevelsAllowed: [SkillLevel]?
    var minAvgScore: Int?
    var maxAvgScore: Int?
    var maxDistanceMiles: Int?
    
    // Convenience aliases for age range display
    var ageMin: Int? { minAge }
    var ageMax: Int? { maxAge }
    
    init(
        genderAllowed: [Gender]? = nil,
        minAge: Int? = nil,
        maxAge: Int? = nil,
        skillLevelsAllowed: [SkillLevel]? = nil,
        minAvgScore: Int? = nil,
        maxAvgScore: Int? = nil,
        maxDistanceMiles: Int? = nil
    ) {
        self.genderAllowed = genderAllowed
        self.minAge = minAge
        self.maxAge = maxAge
        self.skillLevelsAllowed = skillLevelsAllowed
        self.minAvgScore = minAvgScore
        self.maxAvgScore = maxAvgScore
        self.maxDistanceMiles = maxDistanceMiles
    }
    
    var isEmpty: Bool {
        genderAllowed == nil &&
        minAge == nil &&
        maxAge == nil &&
        skillLevelsAllowed == nil &&
        minAvgScore == nil &&
        maxAvgScore == nil &&
        maxDistanceMiles == nil
    }
}

// MARK: - Round Price

struct RoundPrice: Codable {
    let type: PriceType
    var amount: Int?      // Exact price in dollars
    var min: Int?
    var max: Int?
    var currency: String
    var note: String?     // Renamed from notes for consistency
    
    init(
        type: PriceType,
        amount: Int? = nil,
        min: Int? = nil,
        max: Int? = nil,
        currency: String = "USD",
        note: String? = nil
    ) {
        self.type = type
        self.amount = amount
        self.min = min
        self.max = max
        self.currency = currency
        self.note = note
    }
    
    var displayText: String {
        // If exact amount is set, show it
        if let amount = amount, amount > 0 {
            return "$\(amount)"
        }
        
        switch type {
        case .free:
            return "Free"
        case .unknown:
            return "Price TBD"
        case .estimate:
            if let min = min {
                return "~$\(min)"
            }
            return "Price TBD"
        case .range:
            if let min = min, let max = max {
                return "$\(min)-$\(max)"
            } else if let min = min {
                return "$\(min)+"
            }
            return "Price TBD"
        }
    }
    
    // For backward compatibility
    var notes: String? {
        get { note }
        set { note = newValue }
    }
}

// MARK: - Round Enums

enum RoundVisibility: String, Codable, CaseIterable {
    case `public`
    case friends
    
    var displayText: String {
        switch self {
        case .public: return "Public"
        case .friends: return "Friends Only"
        }
    }
    
    var systemImage: String {
        switch self {
        case .public: return "globe"
        case .friends: return "person.2.fill"
        }
    }
    
    /// Join policy is determined by visibility
    /// Public = Request to Join, Friends = Instant Join
    var defaultJoinPolicy: JoinPolicy {
        switch self {
        case .public: return .request
        case .friends: return .instant
        }
    }
}

enum JoinPolicy: String, Codable, CaseIterable {
    case instant
    case request
    
    var displayText: String {
        switch self {
        case .instant: return "Join Instantly"
        case .request: return "Request to Join"
        }
    }
}

enum RoundStatus: String, Codable {
    case open
    case closed
    case canceled
    case completed
    
    var displayText: String {
        rawValue.capitalized
    }
}

enum PriceType: String, Codable, CaseIterable {
    case free
    case estimate
    case range
    case unknown
    
    var displayText: String {
        switch self {
        case .free: return "Free"
        case .estimate: return "Estimate"
        case .range: return "Price Range"
        case .unknown: return "Unknown"
        }
    }
}

enum PriceTier: String, Codable, CaseIterable {
    case free = "free"
    case budget = "$"
    case moderate = "$$"
    case premium = "$$$"
    case luxury = "$$$$"
    
    var displayText: String {
        rawValue
    }
}
