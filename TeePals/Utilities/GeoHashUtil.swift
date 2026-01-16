import Foundation

/// GeoHash encoding and query bounds computation.
/// Based on the standard geohash algorithm (base32 encoding of interleaved lat/lng bits).
enum GeoHashUtil {
    
    // MARK: - Constants
    
    private static let base32Chars: [Character] = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    private static let bitsPerChar = 5
    
    // MARK: - Encode
    
    /// Encode latitude/longitude to a geohash string.
    /// - Parameters:
    ///   - latitude: Latitude (-90 to 90)
    ///   - longitude: Longitude (-180 to 180)
    ///   - precision: Number of characters (1-12, recommended: 9)
    /// - Returns: Geohash string
    static func encode(latitude: Double, longitude: Double, precision: Int = 9) -> String {
        guard precision >= 1 && precision <= 12 else { return "" }
        guard latitude >= -90 && latitude <= 90 else { return "" }
        guard longitude >= -180 && longitude <= 180 else { return "" }
        
        var latRange = (-90.0, 90.0)
        var lngRange = (-180.0, 180.0)
        var isLng = true
        var bits = 0
        var bitCount = 0
        var hash = ""
        
        while hash.count < precision {
            if isLng {
                let mid = (lngRange.0 + lngRange.1) / 2
                if longitude >= mid {
                    bits = (bits << 1) | 1
                    lngRange.0 = mid
                } else {
                    bits = bits << 1
                    lngRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    bits = (bits << 1) | 1
                    latRange.0 = mid
                } else {
                    bits = bits << 1
                    latRange.1 = mid
                }
            }
            
            isLng.toggle()
            bitCount += 1
            
            if bitCount == bitsPerChar {
                hash.append(base32Chars[bits])
                bits = 0
                bitCount = 0
            }
        }
        
        return hash
    }
    
    // MARK: - Decode
    
    /// Decode a geohash string to approximate center point.
    /// - Parameter geohash: Geohash string
    /// - Returns: Tuple of (latitude, longitude) or nil if invalid
    static func decode(_ geohash: String) -> (latitude: Double, longitude: Double)? {
        guard !geohash.isEmpty else { return nil }
        
        var latRange = (-90.0, 90.0)
        var lngRange = (-180.0, 180.0)
        var isLng = true
        
        for char in geohash.lowercased() {
            guard let index = base32Chars.firstIndex(of: char) else { return nil }
            let bits = Int(base32Chars.distance(from: base32Chars.startIndex, to: index))
            
            for i in (0..<bitsPerChar).reversed() {
                let bit = (bits >> i) & 1
                if isLng {
                    let mid = (lngRange.0 + lngRange.1) / 2
                    if bit == 1 {
                        lngRange.0 = mid
                    } else {
                        lngRange.1 = mid
                    }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if bit == 1 {
                        latRange.0 = mid
                    } else {
                        latRange.1 = mid
                    }
                }
                isLng.toggle()
            }
        }
        
        let lat = (latRange.0 + latRange.1) / 2
        let lng = (lngRange.0 + lngRange.1) / 2
        return (lat, lng)
    }
    
    // MARK: - Query Bounds
    
    /// Compute geohash query bounds that cover a circle.
    /// Returns array of (start, end) bounds for Firestore range queries.
    /// - Parameters:
    ///   - centerLat: Center latitude
    ///   - centerLng: Center longitude
    ///   - radiusMeters: Radius in meters
    ///   - precision: Query precision (shorter = larger cells)
    /// - Returns: Array of (start, end) geohash bounds
    static func queryBounds(
        centerLat: Double,
        centerLng: Double,
        radiusMeters: Double,
        precision: Int
    ) -> [(start: String, end: String)] {
        let centerHash = encode(latitude: centerLat, longitude: centerLng, precision: precision)
        guard !centerHash.isEmpty else { return [] }
        
        // Get all neighbors including center
        let neighbors = neighborsWithCenter(of: centerHash)
        
        // Convert each cell to a bound
        var bounds: [(String, String)] = []
        for cell in neighbors {
            let start = cell
            let end = cell + "~" // ~ is after all base32 chars
            bounds.append((start, end))
        }
        
        // Merge adjacent bounds to reduce queries
        return mergeBounds(bounds)
    }
    
    // MARK: - Neighbors
    
    /// Get the 8 neighbors plus the center cell (9 total).
    private static func neighborsWithCenter(of geohash: String) -> [String] {
        var cells = [geohash]
        cells.append(contentsOf: neighbors(of: geohash))
        return Array(Set(cells)).sorted()
    }
    
    /// Get the 8 neighboring geohash cells.
    static func neighbors(of geohash: String) -> [String] {
        guard let center = decode(geohash) else { return [] }
        
        let precision = geohash.count
        let cellSize = cellSizeInDegrees(precision: precision)
        
        var result: [String] = []
        
        // 8 directions: N, NE, E, SE, S, SW, W, NW
        let offsets: [(Double, Double)] = [
            (cellSize.lat, 0),              // N
            (cellSize.lat, cellSize.lng),   // NE
            (0, cellSize.lng),              // E
            (-cellSize.lat, cellSize.lng),  // SE
            (-cellSize.lat, 0),             // S
            (-cellSize.lat, -cellSize.lng), // SW
            (0, -cellSize.lng),             // W
            (cellSize.lat, -cellSize.lng)   // NW
        ]
        
        for offset in offsets {
            let newLat = center.latitude + offset.0
            let newLng = center.longitude + offset.1
            
            // Handle wraparound
            let normalizedLng = normalizeAngle(newLng, min: -180, max: 180)
            let clampedLat = max(-90, min(90, newLat))
            
            let neighborHash = encode(latitude: clampedLat, longitude: normalizedLng, precision: precision)
            if !neighborHash.isEmpty && neighborHash != geohash {
                result.append(neighborHash)
            }
        }
        
        return result
    }
    
    // MARK: - Cell Size
    
    /// Approximate cell size in degrees for a given precision.
    private static func cellSizeInDegrees(precision: Int) -> (lat: Double, lng: Double) {
        // Each character encodes 5 bits, alternating lng/lat
        // Total bits = precision * 5
        // Lng bits = ceil(totalBits / 2), Lat bits = floor(totalBits / 2)
        let totalBits = precision * bitsPerChar
        let lngBits = (totalBits + 1) / 2
        let latBits = totalBits / 2
        
        let latSize = 180.0 / pow(2.0, Double(latBits))
        let lngSize = 360.0 / pow(2.0, Double(lngBits))
        
        return (latSize, lngSize)
    }
    
    // MARK: - Helpers
    
    private static func normalizeAngle(_ angle: Double, min: Double, max: Double) -> Double {
        let range = max - min
        var result = angle
        while result < min { result += range }
        while result >= max { result -= range }
        return result
    }
    
    /// Merge adjacent bounds to reduce number of queries.
    private static func mergeBounds(_ bounds: [(String, String)]) -> [(start: String, end: String)] {
        guard !bounds.isEmpty else { return [] }
        
        let sorted = bounds.sorted { $0.0 < $1.0 }
        var merged: [(String, String)] = []
        var current = sorted[0]
        
        for i in 1..<sorted.count {
            let next = sorted[i]
            // If current end >= next start, merge
            if current.1 >= next.0 {
                current = (current.0, max(current.1, next.1))
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        
        return merged
    }
}

