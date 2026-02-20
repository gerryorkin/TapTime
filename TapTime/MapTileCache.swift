//
//  MapTileCache.swift
//  TapTime
//
//  Pre-warms MapKit tile cache by taking invisible snapshots
//  around saved locations, forcing tiles into the shared URLCache.
//

import MapKit

enum MapTileCache {
    /// Zoom levels to pre-warm (approximate span in degrees).
    /// City-level (~0.15) and neighbourhood-level (~0.03).
    private static let spans: [CLLocationDegrees] = [0.15, 0.03]

    /// Pre-warm map tiles for a set of coordinates.
    /// Runs snapshots concurrently but caps to 4 at a time to stay polite on bandwidth.
    static func prewarm(locations: [CLLocationCoordinate2D]) {
        guard !locations.isEmpty else { return }

        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                var inflight = 0
                for coordinate in locations {
                    for span in spans {
                        if inflight >= 4 {
                            await group.next()
                            inflight -= 1
                        }
                        group.addTask {
                            await snapshotRegion(center: coordinate, span: span)
                        }
                        inflight += 1
                    }
                }
            }
        }
    }

    private static func snapshotRegion(center: CLLocationCoordinate2D, span: CLLocationDegrees) async {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        options.size = CGSize(width: 256, height: 256) // small — just enough to pull tiles
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)
        _ = try? await snapshotter.start()
        // We discard the image — the point is that MapKit fetched the tiles
        // and they're now sitting in URLCache.shared.
    }
}
