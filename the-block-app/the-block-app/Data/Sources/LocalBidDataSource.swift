import Foundation

protocol LocalBidDataSource {
    func read() throws -> Data?
    func write(_ data: Data) throws
}

struct FileBidDataSource: LocalBidDataSource {
    let url: URL

    func read() throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                               withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
