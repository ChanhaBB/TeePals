import SwiftUI

/// A cached version of AsyncImage that stores downloaded images in memory.
/// Significantly improves performance when the same image appears multiple times.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var loader = ImageLoader()
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loader.load(from: url)
                    }
            }
        }
        .onChange(of: url) { _, newUrl in
            loader.load(from: newUrl)
        }
    }
}

// MARK: - Convenience init for simple usage

extension CachedAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?) {
        self.init(url: url) { image in
            image.resizable()
        } placeholder: {
            ProgressView()
        }
    }
}

extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content) {
            ProgressView()
        }
    }
}

// MARK: - Image Loader

@MainActor
final class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    
    private var currentUrl: URL?
    
    func load(from url: URL?) {
        guard let url = url else {
            image = nil
            return
        }
        
        // Don't reload if same URL
        guard url != currentUrl else { return }
        currentUrl = url
        
        // Check cache first
        if let cached = ImageCache.shared.get(for: url) {
            self.image = cached
            return
        }
        
        // Download
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let downloadedImage = UIImage(data: data) {
                    ImageCache.shared.set(downloadedImage, for: url)
                    // Only update if URL hasn't changed
                    if url == currentUrl {
                        self.image = downloadedImage
                    }
                }
            } catch {
                // Silently fail - placeholder will remain visible
            }
        }
    }
}

// MARK: - Image Cache

final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func get(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func set(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 1.0)?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    
    func remove(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
    
    func clearAll() {
        cache.removeAllObjects()
    }
}
