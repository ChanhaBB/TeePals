import Foundation

/// Policy for choosing geohash precision based on search radius.
/// Lower precision = larger cells = fewer queries but more false positives.
/// Higher precision = smaller cells = more queries but fewer false positives.
enum GeoPrecisionPolicy {
    
    // MARK: - Storage Precision
    
    /// Precision used when storing geohash in Firestore.
    /// Always store at high precision (9) for flexibility.
    static let storagePrecision = 9
    
    // MARK: - Query Precision
    
    /// Get the recommended query precision for a given radius.
    /// With "center + 8 neighbors" approach, we cover ~3x cell diameter.
    /// So we choose precision where 3 * cell_size >= 2 * radius.
    /// - Parameter radiusMiles: Search radius in miles
    /// - Returns: Recommended geohash precision for queries
    static func queryPrecision(forRadiusMiles radiusMiles: Double) -> Int {
        // Precision cell sizes (approximate):
        // 3: ~150mi, 4: ~40mi, 5: ~5mi, 6: ~1mi, 7: ~0.15mi
        // Coverage = 3 * cell_size (for 3x3 grid)
        switch radiusMiles {
        case 0..<1:
            return 6      // 3mi coverage
        case 1..<5:
            return 5      // 15mi coverage
        case 5..<50:
            return 4      // 120mi coverage
        case 50..<150:
            return 3      // 450mi coverage
        default:
            return 2      // Very large area
        }
    }
    
    /// Get the recommended query precision for a given radius in meters.
    /// - Parameter radiusMeters: Search radius in meters
    /// - Returns: Recommended geohash precision for queries
    static func queryPrecision(forRadiusMeters radiusMeters: Double) -> Int {
        let radiusMiles = DistanceUtil.metersToMiles(radiusMeters)
        return queryPrecision(forRadiusMiles: radiusMiles)
    }
    
    // MARK: - Approximate Cell Sizes
    
    /// Get approximate cell dimensions for a given precision.
    /// Useful for understanding query coverage.
    /// - Parameter precision: Geohash precision (1-12)
    /// - Returns: Approximate (width, height) in miles
    static func approximateCellSizeMiles(precision: Int) -> (width: Double, height: Double) {
        // Approximate cell sizes at the equator
        // These decrease with latitude but are good estimates
        switch precision {
        case 1: return (2500, 2500)     // ~2500 mi
        case 2: return (625, 312)       // ~600 mi x 300 mi
        case 3: return (156, 156)       // ~150 mi
        case 4: return (39, 19.5)       // ~40 mi x 20 mi
        case 5: return (4.9, 4.9)       // ~5 mi
        case 6: return (1.2, 0.6)       // ~1 mi x 0.6 mi
        case 7: return (0.15, 0.15)     // ~800 ft
        case 8: return (0.038, 0.019)   // ~200 ft x 100 ft
        case 9: return (0.005, 0.005)   // ~25 ft
        default: return (0.001, 0.001)  // Very small
        }
    }
    
    // MARK: - Safety Limits
    
    /// Maximum candidates to fetch across all bounds (cost safety).
    static let maxCandidatesTotal = 2000
    
    /// Maximum candidates per individual bound query.
    static let perBoundLimit = 200
    
    /// Maximum allowed radius in miles.
    static let maxRadiusMiles = 100.0
    
    /// Maximum date window in days.
    static let maxDateWindowDays = 30
    
    // MARK: - Defaults
    
    /// Default search radius in miles.
    static let defaultRadiusMiles = 25.0
    
    /// Default date window in days.
    static let defaultDateWindowDays = 30
}

