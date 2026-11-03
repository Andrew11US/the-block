import Foundation
import UIKit

/// Shared, bounded image work with capacity reserved for the selected detail photo.
@MainActor
final class VehicleImageLoader {
    static let shared = VehicleImageLoader()

    enum Priority: Int {
        case inventory, gallery, detail
    }

    private struct Subscriber {
        let priority: Priority
        let continuation: CheckedContinuation<UIImage, Error>
    }

    private final class Request {
        let id = UUID()
        let url: URL
        let order: Int
        var subscribers: [UUID: Subscriber] = [:]
        var task: URLSessionDataTask?
        var priority: Priority { subscribers.values.map(\.priority).max(by: { $0.rawValue < $1.rawValue }) ?? .inventory }

        init(url: URL, order: Int) {
            self.url = url
            self.order = order
        }
    }

    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()
    private var requests: [URL: Request] = [:]
    private var nextOrder = 0

    init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 8
        self.session = session ?? URLSession(configuration: configuration)
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    static func remoteURL(for value: String) -> URL? {
        guard let url = URL(string: value) else { return nil }
        // Supplied placeholders default to SVG; request a native-decodable PNG.
        guard url.host?.lowercased() == "placehold.co", url.pathExtension.isEmpty,
              !["svg", "png", "jpeg", "jpg", "gif", "webp", "avif"].contains(url.lastPathComponent.lowercased()),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.path += "/png"
        return components.url
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func prefetchGallery(_ urls: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in Set(urls.compactMap(Self.remoteURL)) {
                group.addTask { _ = try? await self.image(for: url, priority: .gallery) }
            }
        }
    }

    func image(for url: URL, priority: Priority) async throws -> UIImage {
        try Task.checkCancellation()
        if let image = cache.object(forKey: url as NSURL) { return image }
        let subscriberID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let request: Request
                if let existing = requests[url] {
                    request = existing
                } else {
                    request = Request(url: url, order: nextOrder)
                    nextOrder += 1
                    requests[url] = request
                }
                request.subscribers[subscriberID] = Subscriber(priority: priority, continuation: continuation)
                updatePriority(request)
                drain()
            }
        } onCancel: {
            Task { @MainActor in self.cancel(subscriberID, for: url) }
        }
    }

    private func cancel(_ subscriberID: UUID, for url: URL) {
        guard let request = requests[url],
              let subscriber = request.subscribers.removeValue(forKey: subscriberID) else { return }
        subscriber.continuation.resume(throwing: CancellationError())
        if request.subscribers.isEmpty {
            requests.removeValue(forKey: url)
            request.task?.cancel()
        } else {
            updatePriority(request)
        }
        drain()
    }

    private func updatePriority(_ request: Request) {
        request.task?.priority = request.priority == .detail
            ? URLSessionTask.highPriority : URLSessionTask.defaultPriority
    }

    private func drain() {
        while requests.values.filter({ $0.task != nil }).count < 8 {
            let runningInventory = requests.values.filter { $0.task != nil && $0.priority == .inventory }.count
            let runningBackground = requests.values.filter { $0.task != nil && $0.priority != .detail }.count
            let next = requests.values
                .filter {
                    guard $0.task == nil else { return false }
                    switch $0.priority {
                    case .inventory: return runningInventory < 6 && runningBackground < 7
                    case .gallery: return runningBackground < 7
                    case .detail: return true
                    }
                }
                .sorted {
                    if $0.priority != $1.priority { return $0.priority.rawValue > $1.priority.rawValue }
                    return $0.order < $1.order
                }.first
            guard let next else { return }
            start(next)
        }
    }

    private func start(_ request: Request) {
        let url = request.url
        let requestID = request.id
        request.task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            // Decode/decompress away from the UI actor before publishing the result.
            let result: Result<UIImage, Error>
            if let error {
                result = .failure(error)
            } else if let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      let data, let image = UIImage(data: data) {
                result = .success(image.preparingForDisplay() ?? image)
            } else {
                result = .failure(URLError(.cannotDecodeContentData))
            }
            Task { @MainActor in self.finish(url, requestID: requestID, result: result) }
        }
        updatePriority(request)
        request.task?.resume()
    }

    private func finish(_ url: URL, requestID: UUID, result: Result<UIImage, Error>) {
        // A cancelled URL may already have a new request; ignore its old completion.
        guard let request = requests[url], request.id == requestID else { return }
        requests.removeValue(forKey: url)
        if case .success(let image) = result {
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            cache.setObject(image, forKey: url as NSURL, cost: cost)
        }
        for subscriber in request.subscribers.values {
            subscriber.continuation.resume(with: result)
        }
        drain()
    }
}
