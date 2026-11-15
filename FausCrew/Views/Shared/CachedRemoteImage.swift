import SwiftUI
import ImageIO

@MainActor
final class RemoteImageStore {
    static let shared = RemoteImageStore()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let cachedImage = cachedImage(for: url) {
            return cachedImage
        }

        if let task = inFlightTasks[url] {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            await Self.downloadImage(for: url)
        }

        inFlightTasks[url] = task
        let image = await task.value
        inFlightTasks[url] = nil

        if let image {
            cache.setObject(image, forKey: url as NSURL, cost: image.cacheCost)
        }

        return image
    }

    @concurrent
    private static func downloadImage(for url: URL) async -> UIImage? {
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                RemoteImageDecoding.isAllowedByteCount(response.expectedContentLength),
                data.count <= RemoteImageDecoding.maximumDownloadBytes
            else { return nil }
            return RemoteImageDecoding.thumbnail(from: data)
        } catch {
            return nil
        }
    }
}

nonisolated enum RemoteImageDecoding {
    static let maximumDownloadBytes = 5 * 1024 * 1024
    // Covers the 90 pt avatar tile's 1.04 selection scale at 3x display scale.
    static let minimumThumbnailShortEdgePixels = 94 * 3

    static func isAllowedByteCount(_ count: Int64) -> Bool {
        count <= Int64(maximumDownloadBytes)
    }

    static func thumbnail(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return nil }

        let longEdge = max(width, height)
        let shortEdge = min(width, height)
        let scale = min(1, Double(minimumThumbnailShortEdgePixels) / Double(shortEdge))
        let maximumPixelSize = min(longEdge, min(1024, Int(ceil(Double(longEdge) * scale))))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failure: () -> Failure

    @State private var loadedImage: UIImage?
    @State private var loadedURL: URL?
    @State private var didFail = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.failure = failure
        _loadedImage = State(initialValue: url.flatMap { RemoteImageStore.shared.cachedImage(for: $0) })
        _loadedURL = State(initialValue: url)
    }

    private var displayedImage: UIImage? {
        if loadedURL == url { return loadedImage }
        return url.flatMap { RemoteImageStore.shared.cachedImage(for: $0) }
    }

    var body: some View {
        Group {
            if let displayedImage {
                content(Image(uiImage: displayedImage))
            } else if loadedURL == url, didFail {
                failure()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        if let url, let cachedImage = RemoteImageStore.shared.cachedImage(for: url) {
            if loadedURL != url || loadedImage !== cachedImage {
                loadedURL = url
                loadedImage = cachedImage
            }
            didFail = false
            return
        }
        if loadedURL == url, loadedImage != nil { return }

        loadedURL = url
        loadedImage = nil
        didFail = false

        guard let url else {
            didFail = true
            return
        }

        let image = await RemoteImageStore.shared.image(for: url)
        guard !Task.isCancelled, loadedURL == url else { return }
        if let image {
            loadedImage = image
        } else {
            didFail = true
        }
    }
}

private extension UIImage {
    var cacheCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
