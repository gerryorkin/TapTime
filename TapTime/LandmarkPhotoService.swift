//
//  LandmarkPhotoService.swift
//  TapTime
//

import SwiftUI
internal import Combine

@MainActor
final class LandmarkPhotoService: ObservableObject {
    static let shared = LandmarkPhotoService()

    /// In-memory cache: country slug -> UIImage
    private var memoryCache: [String: UIImage] = [:]

    /// Track in-flight requests to avoid duplicate fetches
    private var inFlightRequests: Set<String> = []

    /// Countries where Pexels returned no results — don't retry
    private var noResultCountries: Set<String> = []

    private let cacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("LandmarkPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Public API

    /// Clear all cached photos (memory + disk) so they re-fetch with updated queries.
    func clearCache() {
        memoryCache.removeAll()
        inFlightRequests.removeAll()
        noResultCountries.removeAll()
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files { try? FileManager.default.removeItem(at: file) }
        }
        objectWillChange.send()
        print("[LandmarkPhoto] Cache cleared")
    }

    /// Get a landmark photo by cache slug. Returns cached image or nil.
    func photo(forSlug slug: String) -> UIImage? {
        memoryCache[slug]
    }

    /// Request a photo be loaded (from disk cache or network).
    /// Triggers objectWillChange when done so views re-render.
    func loadPhoto(query: String, slug: String) {
        // Already in memory, already fetching, or known empty
        if memoryCache[slug] != nil {
            print("[LandmarkPhoto] Already cached: \(slug)")
            return
        }
        if inFlightRequests.contains(slug) {
            print("[LandmarkPhoto] Already fetching: \(slug)")
            return
        }
        if noResultCountries.contains(slug) { return }

        print("[LandmarkPhoto] Loading: query='\(query)' slug='\(slug)'")
        inFlightRequests.insert(slug)

        Task {
            // 1. Check disk cache
            if let diskImage = loadFromDisk(slug: slug) {
                print("[LandmarkPhoto] Loaded from disk: \(slug)")
                memoryCache[slug] = diskImage
                inFlightRequests.remove(slug)
                objectWillChange.send()
                return
            }

            // 2. Fetch from Pexels
            print("[LandmarkPhoto] Fetching from Pexels: \(query)")
            if let networkImage = await fetchFromPexels(query: query, slug: slug) {
                print("[LandmarkPhoto] Fetched successfully: \(slug)")
                memoryCache[slug] = networkImage
                inFlightRequests.remove(slug)
                objectWillChange.send()
                return
            }

            // No result — remember so we don't retry
            print("[LandmarkPhoto] No result for: \(slug)")
            noResultCountries.insert(slug)
            inFlightRequests.remove(slug)
        }
    }

    // MARK: - Search Query Extraction

    /// Build a search query and cache key from the location name and timezone.
    /// Returns (searchQuery, cacheSlug).
    /// For "Australia/Sydney" -> ("Sydney Australia landmark", "australia_sydney")
    /// For "Your location" -> ("Sydney Australia landmark", "australia_sydney") derived from timezone.
    static func searchInfo(from locationName: String, timeZone: TimeZone) -> (query: String, slug: String) {
        let country: String
        let city: String

        if locationName == "Your location" {
            // Derive from timezone identifier, e.g. "Australia/Sydney"
            if let countryCode = CountryData.timeZoneToCountryCode[timeZone.identifier] {
                let locale = NSLocale(localeIdentifier: "en_US")
                country = locale.displayName(forKey: .countryCode, value: countryCode) ?? ""
            } else {
                country = ""
            }
            let tzParts = timeZone.identifier.split(separator: "/")
            city = tzParts.count >= 2
                ? String(tzParts.last!).replacingOccurrences(of: "_", with: " ")
                : ""
        } else {
            // Standard "Country/City" format
            let parts = locationName.split(separator: "/", maxSplits: 1)
            country = (parts.first.map(String.init) ?? locationName).replacingOccurrences(of: "_", with: " ")
            city = parts.count > 1
                ? String(parts[1]).replacingOccurrences(of: "_", with: " ")
                : ""
        }

        let queryParts = [city, country, "skyline cityscape landmark"].filter { !$0.isEmpty }
        let query = queryParts.joined(separator: " ")
        let slugParts = [country, city].filter { !$0.isEmpty }
        let slug = Self.slug(for: slugParts.joined(separator: "_"))

        return (query, slug)
    }

    // MARK: - Private

    private static func slug(for country: String) -> String {
        country.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "'", with: "")
    }

    private func diskCachePath(slug: String) -> URL {
        cacheDirectory.appendingPathComponent("\(slug).jpg")
    }

    private func loadFromDisk(slug: String) -> UIImage? {
        let path = diskCachePath(slug: slug)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return UIImage(contentsOfFile: path.path)
    }

    private func saveToDisk(data: Data, slug: String) {
        try? data.write(to: diskCachePath(slug: slug))
    }

    private func fetchFromPexels(query: String, slug: String) async -> UIImage? {
        let query = query
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(PexelsConfig.baseURL)/search?query=\(query)&per_page=1&orientation=landscape") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(PexelsConfig.apiKey, forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            // Parse JSON — we only need src.landscape from the first photo
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let photos = json?["photos"] as? [[String: Any]],
                  let firstPhoto = photos.first,
                  let src = firstPhoto["src"] as? [String: String],
                  let imageURLString = src["landscape"],
                  let imageURL = URL(string: imageURLString) else { return nil }

            // Download the actual image
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            guard let image = UIImage(data: imageData) else { return nil }

            saveToDisk(data: imageData, slug: slug)
            return image
        } catch {
            #if DEBUG
            print("[LandmarkPhoto] Failed to fetch for \(query): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
