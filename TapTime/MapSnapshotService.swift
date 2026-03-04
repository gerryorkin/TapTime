//
//  MapSnapshotService.swift
//  TapTime
//

import SwiftUI
import MapKit
import CoreLocation
internal import Combine

@MainActor
final class MapSnapshotService: ObservableObject {
    static let shared = MapSnapshotService()

    /// In-memory cache: slug -> UIImage
    private var memoryCache: [String: UIImage] = [:]

    private init() {
        preloadDiskCache()
    }

    /// Load all disk-cached snapshots into memory at launch for instant display.
    private func preloadDiskCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "png" {
            let slug = file.deletingPathExtension().lastPathComponent
            if let image = UIImage(contentsOfFile: file.path) {
                memoryCache[slug] = image
            }
        }
        #if DEBUG
        print("[MapSnapshot] Preloaded \(memoryCache.count) snapshots from disk")
        #endif
    }

    /// Track in-flight requests to avoid duplicate fetches
    private var inFlightRequests: Set<String> = []

    /// Pending geocode+snapshot work items, processed one at a time
    private var pendingWork: [(locationName: String, timeZone: TimeZone, fallback: CLLocationCoordinate2D, slug: String)] = []
    private var isProcessingQueue = false

    private let cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("MapSnapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Public API

    /// Clear all cached map snapshots (memory + disk).
    func clearCache() {
        memoryCache.removeAll()
        inFlightRequests.removeAll()
        pendingWork.removeAll()
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
        objectWillChange.send()
    }

    /// Get a map snapshot by cache slug. Returns cached image or nil.
    func snapshot(forSlug slug: String) -> UIImage? {
        memoryCache[slug]
    }

    /// Request a map snapshot centred on the city derived from the location name.
    /// Geocodes the city name for accurate centering; falls back to the provided coordinate.
    func loadSnapshot(locationName: String, timeZone: TimeZone, fallbackCoordinate: CLLocationCoordinate2D, slug: String) {
        if memoryCache[slug] != nil { return }
        if inFlightRequests.contains(slug) { return }

        // Check disk cache first (synchronous, no geocoding needed)
        if let diskImage = loadFromDisk(slug: slug) {
            memoryCache[slug] = diskImage
            objectWillChange.send()
            return
        }

        inFlightRequests.insert(slug)
        pendingWork.append((locationName, timeZone, fallbackCoordinate, slug))
        processQueue()
    }

    /// Build a cache slug from the location name (same pattern as LandmarkPhotoService).
    static func slug(for locationName: String, timeZone: TimeZone) -> String {
        let info = LandmarkPhotoService.searchInfo(from: locationName, timeZone: timeZone)
        return "map_\(info.slug)"
    }

    // MARK: - Serial Queue

    /// Process pending work items one at a time to avoid CLGeocoder conflicts.
    private func processQueue() {
        guard !isProcessingQueue, !pendingWork.isEmpty else { return }
        isProcessingQueue = true

        let item = pendingWork.removeFirst()

        Task {
            // Geocode the city name for a proper center
            let center = await geocodeCity(locationName: item.locationName, timeZone: item.timeZone) ?? item.fallback

            // Determine city name length for zoom level
            let cityName: String
            if item.locationName == "Your location" {
                let tzParts = item.timeZone.identifier.split(separator: "/")
                cityName = tzParts.count >= 2 ? String(tzParts.last!).replacingOccurrences(of: "_", with: " ") : ""
            } else {
                let parts = item.locationName.split(separator: "/", maxSplits: 1)
                cityName = parts.count > 1 ? String(parts[1]).replacingOccurrences(of: "_", with: " ") : ""
            }

            // Generate snapshot
            if let snapshotImage = await generateSnapshot(coordinate: center, wideZoom: cityName.count >= 10) {
                memoryCache[item.slug] = snapshotImage
                saveToDisk(image: snapshotImage, slug: item.slug)
                objectWillChange.send()
            }

            inFlightRequests.remove(item.slug)
            isProcessingQueue = false
            processQueue() // process next item
        }
    }

    // MARK: - Private

    /// Geocode the city/country from the location name to get a city-center coordinate.
    private func geocodeCity(locationName: String, timeZone: TimeZone) async -> CLLocationCoordinate2D? {
        let city: String
        let country: String

        if locationName == "Your location" {
            let tzParts = timeZone.identifier.split(separator: "/")
            city = tzParts.count >= 2
                ? String(tzParts.last!).replacingOccurrences(of: "_", with: " ")
                : ""
            if let countryCode = CountryData.timeZoneToCountryCode[timeZone.identifier] {
                let locale = NSLocale(localeIdentifier: "en_US")
                country = locale.displayName(forKey: .countryCode, value: countryCode) ?? ""
            } else {
                country = ""
            }
        } else {
            let parts = locationName.split(separator: "/", maxSplits: 1)
            country = (parts.first.map(String.init) ?? locationName).replacingOccurrences(of: "_", with: " ")
            city = parts.count > 1
                ? String(parts[1]).replacingOccurrences(of: "_", with: " ")
                : ""
        }

        let searchString = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        guard !searchString.isEmpty else { return nil }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(searchString)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    private func diskCachePath(slug: String) -> URL {
        cacheDirectory.appendingPathComponent("\(slug).png")
    }

    private func loadFromDisk(slug: String) -> UIImage? {
        let path = diskCachePath(slug: slug)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return UIImage(contentsOfFile: path.path)
    }

    private func saveToDisk(image: UIImage, slug: String) {
        if let data = image.pngData() {
            try? data.write(to: diskCachePath(slug: slug))
        }
    }

    private func generateSnapshot(coordinate: CLLocationCoordinate2D, wideZoom: Bool = false) async -> UIImage? {
        let span = wideZoom ? 0.45 : 0.18
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        options.size = CGSize(width: 600, height: 200)
        options.mapType = .standard
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            return snapshot.image
        } catch {
            return nil
        }
    }
}
