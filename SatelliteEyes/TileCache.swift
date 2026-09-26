import CoreGraphics
import Foundation
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SatelliteEyes", category: "TileCache")

/// On-disk store of individual map tiles, filled by nearby-imagery prefetching
/// and read when rendering. Entries expire after `maxAge` so imagery refreshes,
/// and `prune()` bounds the directory by age and count.
enum TileCache {
    static let maxAge: TimeInterval = 30 * 24 * 60 * 60
    static let maxFileCount = 10_000

    private static let directoryURL: URL = {
        let directory = URL(fileURLWithPath: FileManager.default.pathForPrivateFile("tiles"), isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    static func fileURL(for tile: MapTile) -> URL {
        let key = "\(tile.source)_\(tile.z)_\(tile.x)_\(tile.y)".md5Digest()
        return directoryURL.appendingPathComponent("tile-\(key)")
    }

    static func hasFreshTile(_ tile: MapTile) -> Bool {
        isFresh(fileURL(for: tile))
    }

    /// The cached image for `tile`, or nil if it is missing, expired, or
    /// undecodable. An undecodable file is deleted so it is fetched again.
    static func image(for tile: MapTile) -> CGImage? {
        let url = fileURL(for: tile)
        guard isFresh(url), let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        guard let image = MapTile.image(from: data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return image
    }

    static func store(_ data: Data, for tile: MapTile) {
        do {
            try data.write(to: fileURL(for: tile), options: .atomic)
        } catch {
            log.error("Failed to write tile cache file: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes expired tiles, then the oldest beyond `maxFileCount`.
    @concurrent
    static func prune() async {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: keys) else { return }

        let cutoff = Date(timeIntervalSinceNow: -maxAge)
        var kept: [(url: URL, date: Date)] = []
        for url in urls {
            let date = (try? url.resourceValues(forKeys: Set(keys)))?.contentModificationDate ?? .distantPast
            if date < cutoff {
                try? FileManager.default.removeItem(at: url)
            } else {
                kept.append((url, date))
            }
        }

        guard kept.count > maxFileCount else { return }
        kept.sort { $0.date > $1.date }
        for entry in kept.dropFirst(maxFileCount) {
            try? FileManager.default.removeItem(at: entry.url)
        }
    }

    @concurrent
    static func removeAll() async {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func isFresh(_ url: URL) -> Bool {
        guard let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        else { return false }
        return date.timeIntervalSinceNow > -maxAge
    }
}
