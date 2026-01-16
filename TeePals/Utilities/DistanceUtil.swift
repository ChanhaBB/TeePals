import Foundation

/// Distance calculation utilities using Haversine formula.
enum DistanceUtil {
    
    // MARK: - Constants
    
    /// Earth's radius in miles
    static let earthRadiusMiles: Double = 3958.8
    
    /// Earth's radius in kilometers
    static let earthRadiusKm: Double = 6371.0
    
    /// Earth's radius in meters
    static let earthRadiusMeters: Double = 6_371_000.0
    
    /// Conversion factor: miles to meters
    static let milesToMeters: Double = 1609.344
    
    /// Conversion factor: meters to miles
    static let metersToMiles: Double = 1.0 / 1609.344
    
    // MARK: - Distance Calculation
    
    /// Calculate distance between two points using Haversine formula.
    /// - Parameters:
    ///   - lat1: Latitude of first point
    ///   - lng1: Longitude of first point
    ///   - lat2: Latitude of second point
    ///   - lng2: Longitude of second point
    /// - Returns: Distance in miles
    static func haversineMiles(
        lat1: Double, lng1: Double,
        lat2: Double, lng2: Double
    ) -> Double {
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusMiles * c
    }
    
    /// Calculate distance between two points using Haversine formula.
    /// - Parameters:
    ///   - lat1: Latitude of first point
    ///   - lng1: Longitude of first point
    ///   - lat2: Latitude of second point
    ///   - lng2: Longitude of second point
    /// - Returns: Distance in meters
    static func haversineMeters(
        lat1: Double, lng1: Double,
        lat2: Double, lng2: Double
    ) -> Double {
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusMeters * c
    }
    
    /// Calculate distance between two GeoLocation points.
    /// - Returns: Distance in miles
    static func distanceMiles(from: GeoLocation, to: GeoLocation) -> Double {
        haversineMiles(
            lat1: from.latitude, lng1: from.longitude,
            lat2: to.latitude, lng2: to.longitude
        )
    }
    
    /// Calculate distance between two GeoLocation points.
    /// - Returns: Distance in meters
    static func distanceMeters(from: GeoLocation, to: GeoLocation) -> Double {
        haversineMeters(
            lat1: from.latitude, lng1: from.longitude,
            lat2: to.latitude, lng2: to.longitude
        )
    }
    
    // MARK: - Conversions
    
    /// Convert miles to meters.
    static func milesToMeters(_ miles: Double) -> Double {
        miles * milesToMeters
    }
    
    /// Convert meters to miles.
    static func metersToMiles(_ meters: Double) -> Double {
        meters * metersToMiles
    }
}

