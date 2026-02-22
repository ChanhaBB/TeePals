import Foundation
import UIKit
import Nuke

/// Service for fetching and caching golf course photos from Google Places API (New).
///
/// **Caching Strategy (Google Places ToS Compliant):**
/// - Memory + disk cache via Nuke's shared `ImagePipeline` (25-day TTL on disk)
/// - Cache key: stable `teepals-course://{placeId}` URL per course
/// - Google Places API (New): Fetch on cache miss only
///
/// **Flow:**
/// 1. Resolve place_id from course name/location (cached in memory)
/// 2. Check Nuke cache for existing photo → return immediately if hit
/// 3. On miss: fetch photo name → download image with auth headers
/// 4. Store in Nuke cache (memory + disk) → return stable URL
@MainActor
final class CoursePhotoService {

    // MARK: - Dependencies

    private let googleAPIKey: String
    private let urlSession: URLSession
    private let bundleIdentifier: String

    // MARK: - Cache

    /// course identifier → place_id (avoids redundant API calls).
    /// Backed by UserDefaults for persistence across app launches.
    private var placeIdCache: [String: String]

    private static let placeIdCacheKey = "teepals_placeIdCache"

    // MARK: - Constants

    private enum Config {
        static let photoMaxWidth = 800
        static let photoMaxHeight = 600
    }

    // MARK: - Init

    init(googleAPIKey: String, urlSession: URLSession = .shared) {
        self.googleAPIKey = googleAPIKey
        self.urlSession = urlSession
        self.bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.teepals.app"
        self.placeIdCache = UserDefaults.standard.dictionary(forKey: Self.placeIdCacheKey) as? [String: String] ?? [:]
    }

    // MARK: - Public API

    /// Fetch photo URL for a course. Returns a stable URL that resolves from Nuke's cache.
    ///
    /// On first call, downloads from Google Places API and caches.
    /// On subsequent calls, returns immediately from cache.
    func fetchPhotoURL(for course: CourseCandidate) async -> URL? {
        let courseKey = generateCourseKey(course: course)

        guard let placeId = await getPlaceId(for: course, courseKey: courseKey) else {
            return nil
        }

        let stableURL = stableCacheURL(for: placeId)
        let request = ImageRequest(url: stableURL)

        if ImagePipeline.shared.cache.containsCachedImage(for: request, caches: .all) {
            return stableURL
        }

        guard let photoName = await getPhotoName(placeId: placeId) else {
            return nil
        }

        guard let imageData = await downloadPhotoData(photoName: photoName) else {
            return nil
        }

        guard let uiImage = UIImage(data: imageData) else {
            print("CoursePhotoService: Failed to decode image data")
            return nil
        }

        let container = ImageContainer(image: uiImage)
        ImagePipeline.shared.cache.storeCachedImage(container, for: request, caches: .all)

        return stableURL
    }

    // MARK: - Stable URL

    /// Deterministic URL used as cache key. Not a real network URL.
    private func stableCacheURL(for placeId: String) -> URL {
        URL(string: "teepals-course://photo/\(placeId)")!
    }

    // MARK: - Place ID Resolution

    private func generateCourseKey(course: CourseCandidate) -> String {
        let name = course.name.lowercased().replacingOccurrences(of: " ", with: "_")
        let city = course.cityLabel.lowercased().replacingOccurrences(of: " ", with: "_")
        let latLng = "\(Int(course.location.latitude * 1000))_\(Int(course.location.longitude * 1000))"
        return "\(name)_\(city)_\(latLng)"
    }

    private func getPlaceId(for course: CourseCandidate, courseKey: String) async -> String? {
        if let cached = placeIdCache[courseKey] {
            return cached
        }

        guard let placeId = await searchPlace(course: course) else {
            return nil
        }

        placeIdCache[courseKey] = placeId
        UserDefaults.standard.set(placeIdCache, forKey: Self.placeIdCacheKey)
        return placeId
    }

    private func searchPlace(course: CourseCandidate) async -> String? {
        let url = URL(string: "https://places.googleapis.com/v1/places:searchText")!

        let requestBody: [String: Any] = [
            "textQuery": "\(course.name) \(course.cityLabel)",
            "locationBias": [
                "circle": [
                    "center": [
                        "latitude": course.location.latitude,
                        "longitude": course.location.longitude
                    ],
                    "radius": 5000.0
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
            let (data, _) = try await urlSession.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let places = json["places"] as? [[String: Any]],
                  let firstPlace = places.first,
                  let placeId = firstPlace["id"] as? String else {
                return nil
            }

            return placeId
        } catch {
            print("CoursePhotoService: Place search failed — \(error)")
            return nil
        }
    }

    // MARK: - Photo Resolution

    private func getPhotoName(placeId: String) async -> String? {
        let url = URL(string: "https://places.googleapis.com/v1/places/\(placeId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(googleAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.setValue("photos", forHTTPHeaderField: "X-Goog-FieldMask")

        do {
            let (data, _) = try await urlSession.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let photos = json["photos"] as? [[String: Any]],
                  let firstPhoto = photos.first,
                  let photoName = firstPhoto["name"] as? String else {
                return nil
            }

            return photoName
        } catch {
            print("CoursePhotoService: Photo name fetch failed — \(error)")
            return nil
        }
    }

    /// Downloads photo bytes with authenticated headers. Returns raw data (not a URL).
    private func downloadPhotoData(photoName: String) async -> Data? {
        let mediaURLString = "https://places.googleapis.com/v1/\(photoName)/media?maxWidthPx=\(Config.photoMaxWidth)&maxHeightPx=\(Config.photoMaxHeight)"

        guard let mediaURL = URL(string: mediaURLString) else { return nil }

        var request = URLRequest(url: mediaURL)
        request.httpMethod = "GET"
        request.setValue(googleAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")

        do {
            let (data, response) = try await urlSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                print("CoursePhotoService: Photo download status \(httpResponse.statusCode)")
                return nil
            }

            return data
        } catch {
            print("CoursePhotoService: Photo download failed — \(error)")
            return nil
        }
    }
}
