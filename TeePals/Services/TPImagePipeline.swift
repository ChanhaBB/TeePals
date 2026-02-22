import Foundation
import Nuke

/// Configures the shared Nuke `ImagePipeline` used by all image loading in the app.
///
/// **Caching strategy:**
/// - Memory cache: automatic via `ImageCache.shared`
/// - Disk cache: `DataCache` with 200 MB limit and 25-day TTL (Google Places API compliance)
/// - HTTP cache policy: `useProtocolCachePolicy` to respect server Cache-Control headers
///
/// Call `TPImagePipeline.configure()` once at app launch, before any images are loaded.
enum TPImagePipeline {

    /// Maximum age for disk-cached entries (25 days, safely under Google's 30-day limit).
    static let maxDiskAge: TimeInterval = 25 * 24 * 60 * 60

    /// Configures `ImagePipeline.shared` with memory + disk caching.
    static func configure() {
        do {
            let dataCache = try DataCache(name: "teepals-image-cache")
            dataCache.sizeLimit = 200 * 1024 * 1024 // 200 MB

            sweepExpiredEntries(in: dataCache.path, maxAge: maxDiskAge)

            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.requestCachePolicy = .useProtocolCachePolicy

            let pipeline = ImagePipeline {
                $0.dataCache = dataCache
                $0.imageCache = ImageCache.shared
                $0.dataLoader = DataLoader(configuration: sessionConfig)
            }

            ImagePipeline.shared = pipeline
        } catch {
            print("TPImagePipeline: Failed to create DataCache — \(error)")
        }
    }

    /// Removes disk cache entries older than `maxAge` for Google Places API ToS compliance.
    private static func sweepExpiredEntries(in cacheDirectory: URL, maxAge: TimeInterval) {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Date().addingTimeInterval(-maxAge)
        var removed = 0
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate,
                  modified < cutoff else { continue }
            try? fileManager.removeItem(at: url)
            removed += 1
        }
        if removed > 0 {
            print("TPImagePipeline: Swept \(removed) expired cache entries")
        }
    }
}
