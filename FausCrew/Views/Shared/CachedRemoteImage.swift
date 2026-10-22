import SwiftUI

@MainActor
final class RemoteImageStore {
    static let shared = RemoteImageStore()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        if let task = inFlightTasks[url] {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = .returnCacheDataElseLoad
                let (data, response) = try await URLSession.shared.data(for: request)
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    (200..<300).contains(httpResponse.statusCode),
                    let image = UIImage(data: data)
                else {
                    return nil
                }
                return image
            } catch {
                return nil
            }
        }

        inFlightTasks[url] = task
        let image = await task.value
        inFlightTasks[url] = nil

        if let image {
            cache.setObject(image, forKey: key, cost: image.cacheCost)
        }

        return image
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failure: () -> Failure

    @State private var loadedImage: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else if didFail {
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
        loadedImage = nil
        didFail = false

        guard let url else {
            didFail = true
            return
        }

        if let image = await RemoteImageStore.shared.image(for: url) {
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
