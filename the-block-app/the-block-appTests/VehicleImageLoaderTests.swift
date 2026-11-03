import Foundation
import Testing
import UIKit
@testable import the_block_app

@Suite(.serialized)
@MainActor
struct VehicleImageLoaderTests {
    private func setup() -> (VehicleImageLoader, URLSession) {
        ImageQueueProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.protocolClasses = [ImageQueueProtocol.self]
        let session = URLSession(configuration: configuration)
        return (VehicleImageLoader(session: session), session)
    }

    private func url(_ name: String) -> URL { URL(string: "https://\(ImageQueueProtocol.host)/\(name)")! }

    private func waitFor(_ predicate: () -> Bool) async throws {
        for _ in 0..<300 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw URLError(.timedOut)
    }

    @Test func reservesDetailCapacityAndLimitsInventoryDownloads() async throws {
        let (loader, session) = setup()
        defer { session.invalidateAndCancel() }
        let rows = (0..<8).map { index in
            let target = url("row-\(index)")
            return Task { try await loader.image(for: target, priority: .inventory) }
        }
        defer { rows.forEach { $0.cancel() } }
        try await waitFor { ImageQueueProtocol.started.count == 6 }
        let detail = Task { try await loader.image(for: url("detail"), priority: .detail) }
        defer { detail.cancel() }
        try await waitFor { ImageQueueProtocol.started.count == 7 }
        #expect(ImageQueueProtocol.started.contains(url("detail")))
        #expect(ImageQueueProtocol.started.filter { $0.lastPathComponent.hasPrefix("row-") }.count == 6)

        // A failed detail must release its slot for another detail, not a seventh row.
        ImageQueueProtocol.finish(url("detail"), data: Data())
        _ = await detail.result
        #expect(ImageQueueProtocol.started.count == 7)
        let nextDetail = Task { try await loader.image(for: url("next-detail"), priority: .detail) }
        defer { nextDetail.cancel() }
        try await waitFor { ImageQueueProtocol.started.contains(url("next-detail")) }
        #expect(ImageQueueProtocol.started.count == 8)
    }

    @Test func preloadsEntireGalleryAndExposesCacheBeforePageAppears() async throws {
        let (loader, session) = setup()
        defer { session.invalidateAndCancel() }
        let urls = (0..<5).map { url("gallery-\($0)") }
        let preload = Task { await loader.prefetchGallery(urls.map(\.absoluteString)) }
        defer { preload.cancel() }
        try await waitFor { ImageQueueProtocol.started.count == 5 }
        let data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        for url in urls { ImageQueueProtocol.finish(url, data: data) }
        await preload.value
        for url in urls {
            let cached = try #require(loader.cachedImage(for: url))
            let selected = try await loader.image(for: url, priority: .detail)
            #expect(cached === selected)
        }
        #expect(ImageQueueProtocol.started.count == 5)
    }

    @Test func galleryPreloadLeavesCapacityForSelectedPhoto() async throws {
        let (loader, session) = setup()
        defer { session.invalidateAndCancel() }
        let urls = (0..<10).map { url("preload-\($0)").absoluteString }
        let preload = Task { await loader.prefetchGallery(urls) }
        defer { preload.cancel() }
        try await waitFor { ImageQueueProtocol.started.count == 7 }
        let selectedURL = url("selected")
        let selected = Task { try await loader.image(for: selectedURL, priority: .detail) }
        defer { selected.cancel() }
        try await waitFor { ImageQueueProtocol.started.count == 8 }
        #expect(ImageQueueProtocol.started.contains(selectedURL))
        preload.cancel()
        await preload.value
        try await waitFor {
            let started = Set(ImageQueueProtocol.started.filter { $0.lastPathComponent.hasPrefix("preload-") })
            return Set(ImageQueueProtocol.stopped).isSuperset(of: started)
        }
    }

    @Test func coalescesSubscribersAndReusesDecodedCache() async throws {
        let (loader, session) = setup()
        defer { session.invalidateAndCancel() }
        let target = url("shared")
        let first = Task { try await loader.image(for: target, priority: .inventory) }
        let second = Task { try await loader.image(for: target, priority: .detail) }
        defer { first.cancel(); second.cancel() }
        try await waitFor { ImageQueueProtocol.started.contains(target) }
        // Let both callers register before cancelling one of them.
        for _ in 0..<20 { await Task.yield() }
        first.cancel()
        _ = await first.result
        #expect(!ImageQueueProtocol.stopped.contains(target))
        let data = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        ImageQueueProtocol.finish(target, data: data)
        let image = try await second.value
        let cached = try await loader.image(for: target, priority: .detail)
        #expect(image === cached)
        #expect(ImageQueueProtocol.started.filter { $0 == target }.count == 1)
    }

    @Test func cancelsOffscreenWorkAndDrainsQueue() async throws {
        let (loader, session) = setup()
        defer { session.invalidateAndCancel() }
        let running = (0..<6).map { index in
            let target = url("cancel-\(index)")
            return Task { try await loader.image(for: target, priority: .inventory) }
        }
        defer { running.forEach { $0.cancel() } }
        try await waitFor { ImageQueueProtocol.started.count == 6 }
        let queuedURL = url("cancel-queued")
        let queued = Task { try await loader.image(for: queuedURL, priority: .inventory) }
        for _ in 0..<20 { await Task.yield() }
        queued.cancel()
        _ = await queued.result
        #expect(!ImageQueueProtocol.started.contains(queuedURL))

        let replacementURL = url("replacement")
        let replacement = Task { try await loader.image(for: replacementURL, priority: .inventory) }
        defer { replacement.cancel() }
        running[0].cancel()
        _ = await running[0].result
        try await waitFor { ImageQueueProtocol.started.contains(replacementURL) }
        #expect(ImageQueueProtocol.stopped.contains(url("cancel-0")))
    }
}

private final class ImageQueueProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var pending: [URL: ImageQueueProtocol] = [:]
    nonisolated(unsafe) private static var starts: [URL] = []
    nonisolated(unsafe) private static var stops: [URL] = []
    nonisolated(unsafe) private static var currentHost = "images.test"

    nonisolated static var host: String { lock.withLock { currentHost } }
    nonisolated static var started: [URL] { lock.withLock { starts.filter { $0.host == currentHost } } }
    nonisolated static var stopped: [URL] { lock.withLock { stops.filter { $0.host == currentHost } } }

    nonisolated static func reset() {
        // Cancellation callbacks from the previous session can arrive after reset.
        lock.withLock {
            currentHost = "\(UUID().uuidString.lowercased()).images.test"
            pending = [:]; starts = []; stops = []
        }
    }

    nonisolated override class func canInit(with request: URLRequest) -> Bool { true }
    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    nonisolated override func startLoading() {
        guard let url = request.url else { return }
        Self.lock.withLock {
            Self.pending[url] = self
            Self.starts.append(url)
        }
    }

    nonisolated override func stopLoading() {
        guard let url = request.url else { return }
        Self.lock.withLock {
            if Self.pending[url] === self { Self.pending.removeValue(forKey: url) }
            Self.stops.append(url)
        }
    }

    nonisolated static func finish(_ url: URL, data: Data) {
        guard let request = lock.withLock({ pending.removeValue(forKey: url) }) else { return }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        request.client?.urlProtocol(request, didReceive: response, cacheStoragePolicy: .notAllowed)
        request.client?.urlProtocol(request, didLoad: data)
        request.client?.urlProtocolDidFinishLoading(request)
    }
}
