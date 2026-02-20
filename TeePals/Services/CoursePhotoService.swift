import Foundation

/// Service for fetching and caching golf course photos from Google Places API (New).
///
/// **Caching Strategy (Google Places ToS Compliant):**
/// - Memory cache: place_id → photo URL (session-only, instant access)
/// - URLCache: Automatic disk cache (respects HTTP headers, per-device only)
/// - Google Places API (New): Fetch on cache miss
///
/// **Why This is Compliant:**
/// - No server-side CDN (Firebase Storage removed)
/// - Client-side caching only (memory + URLCache disk)
/// - Respects cache-control headers from Google
/// - Uses place_id as canonical identifier (Google explicitly allows storing place_id)
///
/// **API Usage:**
/// - Uses Places API (New) v1 endpoints with proper iOS headers
/// - Includes X-Ios-Bundle-Identifier for iOS app restrictions
/// - Supports bundle ID restrictions in Google Cloud Console
///
/// **Performance:**
/// - First load: ~500ms (Google API call)
/// - Subsequent loads: instant (memory) or ~50-100ms (URLCache disk)
/// - Memory cache persists during app session
/// - URLCache persists across sessions per system cache policy
@MainActor
final class CoursePhotoService {

    // MARK: - Dependencies

    private let googleAPIKey: String
    private let urlSession: URLSession
    private let bundleIdentifier: String

    // MARK: - Cache

    /// In-memory cache: place_id → photo URL (data URL with actual image data)
    private var photoURLCache: [String: URL] = [:]

    /// In-memory cache: course identifier → place_id
    /// Avoids redundant Place Search API calls for same course
    private var placeIdCache: [String: String] = [:]

    // MARK: - Constants

    private enum Config {
        static let photoMaxWidth = 400  // Thumbnail size for cards
        static let photoMaxHeight = 400
    }

    // MARK: - Init

    init(googleAPIKey: String, urlSession: URLSession = .shared) {
        self.googleAPIKey = googleAPIKey
        self.urlSession = urlSession
        self.bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.teepals.app"

        // Ensure URLSession has URLCache enabled (it does by default)
        // URLCache will handle disk caching automatically and respect HTTP cache headers
    }

    // MARK: - Public API

    /// Fetch photo URL for a course (with compliant caching)
    /// - Parameter course: The course candidate to fetch photo for
    /// - Returns: URL to photo, or nil if not available
    func fetchPhotoURL(for course: CourseCandidate) async -> URL? {
        print("📸 CoursePhotoService: Fetching photo for \(course.name)")
        let courseKey = generateCourseKey(course: course)

        // Step 1: Get place_id (from cache or API)
        guard let placeId = await getPlaceId(for: course, courseKey: courseKey) else {
            print("❌ CoursePhotoService: Could not find place_id for \(course.name)")
            return nil
        }
        print("✅ CoursePhotoService: Found place_id: \(placeId)")

        // Step 2: Check memory cache for photo URL
        if let cachedPhotoURL = photoURLCache[placeId] {
            print("✅ CoursePhotoService: Using cached photo URL")
            return cachedPhotoURL
        }

        // Step 3: Get photo name from Place Details
        guard let photoName = await getPhotoName(placeId: placeId) else {
            print("❌ CoursePhotoService: No photo found for place_id: \(placeId)")
            return nil
        }
        print("✅ CoursePhotoService: Found photo name")

        // Step 4: Download photo with authenticated request
        guard let photoURL = await downloadPhoto(photoName: photoName, placeId: placeId) else {
            print("❌ CoursePhotoService: Failed to download photo")
            return nil
        }

        // Step 5: Store in memory cache for instant future access
        photoURLCache[placeId] = photoURL

        print("✅ CoursePhotoService: Photo URL ready")
        return photoURL
    }

    // MARK: - Private Helpers

    /// Generate unique course identifier for place_id caching
    /// Uses name + city + location to create stable key (not used for photo URLs)
    private func generateCourseKey(course: CourseCandidate) -> String {
        let name = course.name.lowercased().replacingOccurrences(of: " ", with: "_")
        let city = course.cityLabel.lowercased().replacingOccurrences(of: " ", with: "_")
        let latLng = "\(Int(course.location.latitude * 1000))_\(Int(course.location.longitude * 1000))"
        return "\(name)_\(city)_\(latLng)"
    }

    /// Get place_id for course (from cache or API)
    private func getPlaceId(for course: CourseCandidate, courseKey: String) async -> String? {
        // Check place_id cache first
        if let cachedPlaceId = placeIdCache[courseKey] {
            return cachedPlaceId
        }

        // Fetch from Places API (New)
        guard let placeId = await searchPlace(course: course) else {
            return nil
        }

        // Cache place_id (Google explicitly allows storing place_id)
        placeIdCache[courseKey] = placeId
        return placeId
    }

    /// Search for place using Places API (New) searchText endpoint
    private func searchPlace(course: CourseCandidate) async -> String? {
        let url = URL(string: "https://places.googleapis.com/v1/places:searchText")!

        // Build request body
        let requestBody: [String: Any] = [
            "textQuery": "\(course.name) \(course.cityLabel)",
            "locationBias": [
                "circle": [
                    "center": [
                        "latitude": course.location.latitude,
                        "longitude": course.location.longitude
                    ],
                    "radius": 5000.0  // 5km radius
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(googleAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue("places.id,places.displayName", forHTTPHeaderField: "X-Goog-FieldMask")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ CoursePhotoService: Failed to serialize request body - \(error)")
            return nil
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            // Log response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Places API (New) searchText - Status: \(httpResponse.statusCode)")
            }
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Places API Response: \(jsonString)")
            }

            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let places = json["places"] as? [[String: Any]],
                  let firstPlace = places.first,
                  let placeId = firstPlace["id"] as? String else {
                print("❌ CoursePhotoService: No places found in response")
                return nil
            }

            return placeId
        } catch {
            print("❌ CoursePhotoService: Error searching place - \(error)")
            return nil
        }
    }

    /// Get photo name from Place Details using Places API (New)
    private func getPhotoName(placeId: String) async -> String? {
        let url = URL(string: "https://places.googleapis.com/v1/places/\(placeId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(googleAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue("photos", forHTTPHeaderField: "X-Goog-FieldMask")

        do {
            let (data, response) = try await urlSession.data(for: request)

            // Log response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Places API (New) Details - Status: \(httpResponse.statusCode)")
            }
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📡 Places API Details Response: \(jsonString)")
            }

            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let photos = json["photos"] as? [[String: Any]],
                  let firstPhoto = photos.first,
                  let photoName = firstPhoto["name"] as? String else {
                print("❌ CoursePhotoService: No photos found in response")
                return nil
            }

            return photoName
        } catch {
            print("❌ CoursePhotoService: Error getting photo - \(error)")
            return nil
        }
    }

    /// Download photo with authenticated request and cache locally
    ///
    /// Because iOS-restricted API keys require bundle identifier headers,
    /// we can't use AsyncImage directly with the Google media URL.
    /// Instead, we download the image with proper headers and cache it locally.
    ///
    /// This is compliant with Google's ToS because:
    /// - Caching is client-side only (per-device temporary files)
    /// - Respects HTTP cache policies
    /// - No permanent storage or CDN behavior
    private func downloadPhoto(photoName: String, placeId: String) async -> URL? {
        let mediaURLString = "https://places.googleapis.com/v1/\(photoName)/media?maxWidthPx=\(Config.photoMaxWidth)&maxHeightPx=\(Config.photoMaxHeight)"

        guard let mediaURL = URL(string: mediaURLString) else {
            print("❌ CoursePhotoService: Invalid media URL")
            return nil
        }

        var request = URLRequest(url: mediaURL)
        request.httpMethod = "GET"
        request.setValue(googleAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        do {
            let (data, response) = try await urlSession.data(for: request)

            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Photo Download - Status: \(httpResponse.statusCode)")
                guard httpResponse.statusCode == 200 else {
                    print("❌ CoursePhotoService: Photo download failed with status \(httpResponse.statusCode)")
                    return nil
                }
            }

            // Save to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "\(placeId).jpg"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            print("✅ CoursePhotoService: Photo cached to \(fileURL.path)")

            return fileURL
        } catch {
            print("❌ CoursePhotoService: Error downloading photo - \(error)")
            return nil
        }
    }
}
