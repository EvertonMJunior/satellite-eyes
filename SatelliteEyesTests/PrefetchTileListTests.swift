import CoreLocation
import Foundation
import Testing

@testable import Satellite_Eyes

@Suite("Prefetch tile selection")
struct PrefetchTileListTests {

    static let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    @Test("The tile under the coordinate comes first")
    func nearestTileFirst() {
        let tiles = MapImage.prefetchTileList(around: Self.london, source: "s", zoomLevel: 15, radiusMeters: 2000)
        let center = MapTile.tile(for: Self.london, source: "s", zoomLevel: 15)

        #expect(tiles.first?.x == center.x)
        #expect(tiles.first?.y == center.y)
        #expect(tiles.count > 1)
    }

    @Test("No tile is listed twice")
    func tilesAreUnique() {
        let tiles = MapImage.prefetchTileList(around: Self.london, source: "s", zoomLevel: 16, radiusMeters: 5000)
        let keys = Set(tiles.map { "\($0.x)/\($0.y)" })

        #expect(keys.count == tiles.count)
    }

    @Test("A radius too large for the zoom level keeps the nearest tiles rather than none")
    func overLargeAreaIsCapped() {
        let tiles = MapImage.prefetchTileList(around: Self.london, source: "s", zoomLevel: 20, radiusMeters: 10_000)
        let center = MapTile.tile(for: Self.london, source: "s", zoomLevel: 20)

        #expect(tiles.count == 2500)
        #expect(tiles.first?.x == center.x)
        #expect(tiles.first?.y == center.y)
    }

    @Test("Tiles stay inside the grid at the antimeridian and the poles")
    func tilesStayInGrid() {
        let corners = [
            CLLocationCoordinate2D(latitude: 85, longitude: 179.99),
            CLLocationCoordinate2D(latitude: -85, longitude: -179.99),
        ]
        for coordinate in corners {
            let tiles = MapImage.prefetchTileList(around: coordinate, source: "s", zoomLevel: 10, radiusMeters: 20_000)
            #expect(!tiles.isEmpty)
            #expect(tiles.allSatisfy { $0.x < 1024 && $0.y < 1024 })
        }
    }

    @Test("A zero radius prefetches nothing")
    func zeroRadius() {
        #expect(MapImage.prefetchTileList(around: Self.london, source: "s", zoomLevel: 15, radiusMeters: 0).isEmpty)
    }
}
