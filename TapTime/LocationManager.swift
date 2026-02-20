//
//  LocationManager.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import Foundation
import CoreLocation
import MapKit
internal import Combine

struct SearchResult: Identifiable {
    let id = UUID()
    let name: String           // e.g. "Newcastle upon Tyne"
    let subtitle: String       // e.g. "England, United Kingdom"
    let coordinate: CLLocationCoordinate2D
    let timeZone: TimeZone
}

// MARK: - Country & Capital City Data (not MainActor — loads instantly)
nonisolated enum CountryData {
    /// Maps lowercase country name → ISO code (e.g. "australia" → "AU")
    static let countryNameToCode: [String: String] = {
        var map: [String: String] = [:]
        let locale = NSLocale(localeIdentifier: "en_US")
        for code in NSLocale.isoCountryCodes {
            if let name = locale.displayName(forKey: .countryCode, value: code) {
                map[name.lowercased()] = code
            }
        }
        map["usa"] = "US"; map["us"] = "US"
        map["uk"] = "GB"; map["england"] = "GB"; map["britain"] = "GB"; map["great britain"] = "GB"
        map["uae"] = "AE"; map["south korea"] = "KR"; map["north korea"] = "KP"
        map["russia"] = "RU"; map["nz"] = "NZ"
        return map
    }()

    /// Maps ISO country code → timezone identifiers for countries with multiple zones
    /// Single-timezone countries are handled via capital city geocoding
    private static let multiZoneCountries: [String: [String]] = [
        "US": ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu"],
        "AU": ["Australia/Sydney", "Australia/Adelaide", "Australia/Darwin", "Australia/Perth", "Australia/Brisbane"],
        "CA": ["America/St_Johns", "America/Halifax", "America/Toronto", "America/Winnipeg", "America/Edmonton", "America/Vancouver"],
        "RU": ["Europe/Moscow", "Europe/Samara", "Asia/Yekaterinburg", "Asia/Omsk", "Asia/Krasnoyarsk", "Asia/Irkutsk", "Asia/Yakutsk", "Asia/Vladivostok", "Asia/Kamchatka"],
        "BR": ["America/Sao_Paulo", "America/Manaus", "America/Rio_Branco", "America/Noronha"],
        "CN": ["Asia/Shanghai"],
        "IN": ["Asia/Kolkata"],
        "MX": ["America/Mexico_City", "America/Chihuahua", "America/Tijuana"],
        "ID": ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"],
        "CL": ["America/Santiago", "Pacific/Easter"],
        "NZ": ["Pacific/Auckland", "Pacific/Chatham"],
        "PT": ["Europe/Lisbon", "Atlantic/Azores"],
        "ES": ["Europe/Madrid", "Atlantic/Canary"],
        "GB": ["Europe/London"],
        "FR": ["Europe/Paris"],
        "DE": ["Europe/Berlin"],
        "JP": ["Asia/Tokyo"],
        "KR": ["Asia/Seoul"],
        "ZA": ["Africa/Johannesburg"],
        "AR": ["America/Argentina/Buenos_Aires"],
        "EG": ["Africa/Cairo"],
        "NG": ["Africa/Lagos"],
        "KE": ["Africa/Nairobi"],
        "AE": ["Asia/Dubai"],
        "SA": ["Asia/Riyadh"],
        "TH": ["Asia/Bangkok"],
        "SG": ["Asia/Singapore"],
        "MY": ["Asia/Kuala_Lumpur"],
        "PH": ["Asia/Manila"],
        "PK": ["Asia/Karachi"],
        "BD": ["Asia/Dhaka"],
        "TR": ["Europe/Istanbul"],
        "UA": ["Europe/Kyiv"],
        "PL": ["Europe/Warsaw"],
        "IT": ["Europe/Rome"],
        "SE": ["Europe/Stockholm"],
        "NO": ["Europe/Oslo"],
        "FI": ["Europe/Helsinki"],
        "DK": ["Europe/Copenhagen"],
        "NL": ["Europe/Amsterdam"],
        "BE": ["Europe/Brussels"],
        "CH": ["Europe/Zurich"],
        "AT": ["Europe/Vienna"],
        "GR": ["Europe/Athens"],
        "IE": ["Europe/Dublin"],
        "IL": ["Asia/Jerusalem"],
        "CO": ["America/Bogota"],
        "PE": ["America/Lima"],
        "VE": ["America/Caracas"],
        "EC": ["America/Guayaquil", "Pacific/Galapagos"],
    ]

    /// Maps timezone identifier → country code (reverse of multiZoneCountries)
    static let timeZoneToCountryCode: [String: String] = {
        var map: [String: String] = [:]
        for (code, identifiers) in multiZoneCountries {
            for id in identifiers {
                map[id] = code
            }
        }
        return map
    }()

    /// Build a friendly display name like "Canada/Toronto" from a timezone identifier
    static func friendlyName(for identifier: String) -> String {
        let components = identifier.split(separator: "/")
        let city = components.count >= 2
            ? String(components.last!).replacingOccurrences(of: "_", with: " ")
            : identifier

        // Look up the country name from our timezone → country code mapping
        if let countryCode = timeZoneToCountryCode[identifier] {
            let locale = NSLocale(localeIdentifier: "en_US")
            if let countryName = locale.displayName(forKey: .countryCode, value: countryCode) {
                return "\(countryName)/\(city)"
            }
        }

        // Fallback: return the raw identifier as-is
        return identifier
    }

    /// Returns true if the given country code has more than one distinct timezone
    static func countryHasMultipleTimeZones(_ countryCode: String) -> Bool {
        guard let identifiers = multiZoneCountries[countryCode.uppercased()] else {
            return false
        }
        // Check distinct UTC offsets, not just identifier count
        var seenOffsets = Set<Int>()
        for id in identifiers {
            if let tz = TimeZone(identifier: id) {
                seenOffsets.insert(tz.secondsFromGMT())
            }
        }
        return seenOffsets.count > 1
    }

    /// For pill display: show just the country if it has a single timezone,
    /// or "Country/City" if the country spans multiple timezones.
    /// Input is a locationName in "Country/City" format.
    static func pillDisplayName(for locationName: String, timeZone: TimeZone) -> String {
        let parts = locationName.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return locationName }

        let country = String(parts[0])

        // Look up the country code from the timezone
        if let countryCode = timeZoneToCountryCode[timeZone.identifier],
           countryHasMultipleTimeZones(countryCode) {
            return locationName  // Show full "Country/City"
        }

        return country  // Just the country name
    }

    static func timeZones(for countryCode: String) -> [TimeZone] {
        guard let identifiers = multiZoneCountries[countryCode.uppercased()] else {
            // For countries not in our map, try to find via capital city
            return []
        }
        var result: [TimeZone] = []
        var seenOffsets = Set<Int>()
        for id in identifiers {
            guard let tz = TimeZone(identifier: id) else { continue }
            let offset = tz.secondsFromGMT()
            if !seenOffsets.contains(offset) {
                seenOffsets.insert(offset)
                result.append(tz)
            }
        }
        return result.sorted { $0.secondsFromGMT() < $1.secondsFromGMT() }
    }

    static let capitalCities: [String: String] = [
        "kabul": "AF", "tirana": "AL", "algiers": "DZ", "andorra la vella": "AD",
        "luanda": "AO", "buenos aires": "AR", "yerevan": "AM", "canberra": "AU",
        "vienna": "AT", "baku": "AZ", "nassau": "BS", "manama": "BH", "dhaka": "BD",
        "bridgetown": "BB", "minsk": "BY", "brussels": "BE", "belmopan": "BZ",
        "porto-novo": "BJ", "thimphu": "BT", "la paz": "BO", "sucre": "BO",
        "sarajevo": "BA", "gaborone": "BW", "brasilia": "BR", "bandar seri begawan": "BN",
        "sofia": "BG", "ouagadougou": "BF", "gitega": "BI", "phnom penh": "KH",
        "yaounde": "CM", "ottawa": "CA", "praia": "CV", "bangui": "CF",
        "n'djamena": "TD", "santiago": "CL", "beijing": "CN", "bogota": "CO",
        "moroni": "KM", "kinshasa": "CD", "brazzaville": "CG", "san jose": "CR",
        "zagreb": "HR", "havana": "CU", "nicosia": "CY", "prague": "CZ",
        "copenhagen": "DK", "djibouti": "DJ", "roseau": "DM", "santo domingo": "DO",
        "quito": "EC", "cairo": "EG", "san salvador": "SV", "malabo": "GQ",
        "asmara": "ER", "tallinn": "EE", "addis ababa": "ET", "suva": "FJ",
        "helsinki": "FI", "paris": "FR", "libreville": "GA", "banjul": "GM",
        "tbilisi": "GE", "berlin": "DE", "accra": "GH", "athens": "GR",
        "guatemala city": "GT", "conakry": "GN", "bissau": "GW", "georgetown": "GY",
        "port-au-prince": "HT", "tegucigalpa": "HN", "budapest": "HU",
        "reykjavik": "IS", "new delhi": "IN", "delhi": "IN", "jakarta": "ID",
        "tehran": "IR", "baghdad": "IQ", "dublin": "IE", "jerusalem": "IL",
        "rome": "IT", "kingston": "JM", "tokyo": "JP", "amman": "JO",
        "astana": "KZ", "nairobi": "KE", "tarawa": "KI", "pyongyang": "KP",
        "seoul": "KR", "kuwait city": "KW", "bishkek": "KG", "vientiane": "LA",
        "riga": "LV", "beirut": "LB", "maseru": "LS", "monrovia": "LR",
        "tripoli": "LY", "vaduz": "LI", "vilnius": "LT", "luxembourg": "LU",
        "antananarivo": "MG", "lilongwe": "MW", "kuala lumpur": "MY", "male": "MV",
        "bamako": "ML", "valletta": "MT", "nouakchott": "MR", "port louis": "MU",
        "mexico city": "MX", "chisinau": "MD", "monaco": "MC", "ulaanbaatar": "MN",
        "podgorica": "ME", "rabat": "MA", "maputo": "MZ", "naypyidaw": "MM",
        "windhoek": "NA", "kathmandu": "NP", "amsterdam": "NL", "wellington": "NZ",
        "managua": "NI", "niamey": "NE", "abuja": "NG", "oslo": "NO", "muscat": "OM",
        "islamabad": "PK", "panama city": "PA", "port moresby": "PG", "asuncion": "PY",
        "lima": "PE", "manila": "PH", "warsaw": "PL", "lisbon": "PT", "doha": "QA",
        "bucharest": "RO", "moscow": "RU", "kigali": "RW", "riyadh": "SA",
        "dakar": "SN", "belgrade": "RS", "victoria": "SC", "freetown": "SL",
        "singapore": "SG", "bratislava": "SK", "ljubljana": "SI", "honiara": "SB",
        "mogadishu": "SO", "pretoria": "ZA", "cape town": "ZA", "madrid": "ES",
        "colombo": "LK", "khartoum": "SD", "paramaribo": "SR", "mbabane": "SZ",
        "stockholm": "SE", "bern": "CH", "damascus": "SY", "taipei": "TW",
        "dushanbe": "TJ", "dodoma": "TZ", "bangkok": "TH", "lome": "TG",
        "nuku'alofa": "TO", "port of spain": "TT", "tunis": "TN", "ankara": "TR",
        "ashgabat": "TM", "kampala": "UG", "kyiv": "UA", "kiev": "UA",
        "abu dhabi": "AE", "london": "GB", "washington": "US", "washington dc": "US",
        "washington d.c.": "US", "montevideo": "UY", "tashkent": "UZ",
        "port vila": "VU", "caracas": "VE", "hanoi": "VN", "sanaa": "YE",
        "lusaka": "ZM", "harare": "ZW",
    ]

    /// All searchable names: country display names + capital city names
    static let allSearchableNames: [String] = {
        let locale = NSLocale(localeIdentifier: "en_US")
        var names: [String] = []

        // Country display names
        for code in NSLocale.isoCountryCodes {
            if let name = locale.displayName(forKey: .countryCode, value: code) {
                names.append(name)
            }
        }
        // Capital city names (title-cased)
        for key in capitalCities.keys {
            names.append(key.capitalized)
        }
        // Common aliases
        names.append(contentsOf: ["USA", "US", "UK", "England", "Britain", "Great Britain", "UAE", "South Korea", "North Korea", "Russia", "NZ"])

        return names.sorted()
    }()

    /// Find the best autocomplete match for a prefix
    static func autocomplete(prefix: String) -> String? {
        guard prefix.count >= 2 else { return nil }
        let lower = prefix.lowercased()
        return allSearchableNames.first { $0.lowercased().hasPrefix(lower) }
    }
}

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var userTimeZone: TimeZone = .current
    @Published var savedLocations: [SavedLocation] = [] {
        didSet {
            saveLocations()
        }
    }

    /// Set locations with automatic sorting. Use this instead of assigning savedLocations directly.
    func setLocationsSorted(_ locations: [SavedLocation]) {
        savedLocations = locationsSortedByTime(locations)
    }
    
    private let locationManager = CLLocationManager()
    private let savedLocationsKey = "savedLocations"
    private var isAddingLocation = false
    
    // Cache to limit geocoding requests
    private var geocodingCache: [String: (coordinate: CLLocationCoordinate2D, timeZone: TimeZone)] = [:]
    private let maxCacheSize = 50
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        // Request location authorization
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        locationManager.startUpdatingLocation()
        
        // Set a default user timezone
        userTimeZone = TimeZone.current
        
        // Load saved locations
        loadLocations()
    }
    
    // MARK: - Sorting
    /// Returns locations sorted by their current local date+time (earliest first).
    /// Uses UTC offset so that date differences (e.g. tomorrow vs today) are handled correctly.
    private func locationsSortedByTime(_ locations: [SavedLocation]) -> [SavedLocation] {
        let now = Date()
        return locations.sorted { a, b in
            a.timeZone.secondsFromGMT(for: now) < b.timeZone.secondsFromGMT(for: now)
        }
    }

    // MARK: - Persistence
    private func saveLocations() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(savedLocations)
            UserDefaults.standard.set(data, forKey: savedLocationsKey)
        } catch {
            print("Failed to save locations: \(error.localizedDescription)")
        }
    }
    
    private func loadLocations() {
        guard let data = UserDefaults.standard.data(forKey: savedLocationsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([SavedLocation].self, from: data)
            savedLocations = locationsSortedByTime(decoded)
        } catch {
            print("Failed to load locations: \(error.localizedDescription)")
        }
    }

    /// Append a location and re-sort by timezone offset
    private func appendAndSort(_ location: SavedLocation) {
        var updated = savedLocations
        updated.append(location)
        savedLocations = locationsSortedByTime(updated)
    }
    
    /// Result of attempting to add a location
    enum AddLocationResult {
        case success
        case duplicate
        case limitReached
        case failed
    }

    /// Check if a timezone is already saved
    func hasTimeZone(_ timeZone: TimeZone) -> Bool {
        savedLocations.contains { $0.timeZone.identifier == timeZone.identifier }
    }

    /// Buzz pattern for duplicate / limit reached
    private func buzzError() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impactFeedback.impactOccurred(intensity: 1.0)
        }
    }

    func addLocation(at coordinate: CLLocationCoordinate2D) async -> AddLocationResult {
        guard !isAddingLocation else {
            return .failed
        }
        guard savedLocations.count < 10 else {
            buzzError()
            return .limitReached
        }
        isAddingLocation = true
        defer { isAddingLocation = false }
        
        // Check cache first
        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)"
        if let cached = geocodingCache[cacheKey] {
            let timeZone = cached.timeZone
            if hasTimeZone(timeZone) {
                buzzError()
                return .duplicate
            }
            let city = timeZone.identifier.split(separator: "/").last
                .map { String($0).replacingOccurrences(of: "_", with: " ") }
                ?? timeZone.identifier
            let name = CountryData.friendlyName(for: timeZone.identifier)
            let savedLocation = SavedLocation(
                coordinate: cached.coordinate,
                timeZone: timeZone,
                locationName: name
            )
            appendAndSort(savedLocation)
            print("✅ Added location from cache: \(name)")
            return .success
        }

        // Get timezone for the coordinate using MapKit reverse geocoding
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        guard let request = MKReverseGeocodingRequest(location: location) else {
            print("❌ Failed to create reverse geocoding request")
            return .failed
        }

        do {
            let mapItems = try await request.mapItems

            guard let firstItem = mapItems.first else {
                print("🌊 No map items found - likely ocean or uninhabited area")
                return .failed
            }

            let placemark = firstItem.placemark
            let hasValidAddress = placemark.country != nil || placemark.administrativeArea != nil

            guard hasValidAddress else {
                print("🌊 No country or administrative area - likely ocean")
                return .failed
            }

            let timeZone = firstItem.timeZone ?? TimeZone.current

            // Check for duplicate timezone
            if hasTimeZone(timeZone) {
                buzzError()
                return .duplicate
            }

            // Build a friendly name like "Canada/Toronto" using the placemark's country
            let city = timeZone.identifier.split(separator: "/").last
                .map { String($0).replacingOccurrences(of: "_", with: " ") }
                ?? timeZone.identifier
            let name: String
            if let country = placemark.country {
                name = "\(country)/\(city)"
            } else {
                name = CountryData.friendlyName(for: timeZone.identifier)
            }
            
            // Cache the result
            cacheGeocoding(key: cacheKey, coordinate: coordinate, timeZone: timeZone)

            let savedLocation = SavedLocation(
                coordinate: coordinate,
                timeZone: timeZone,
                locationName: name
            )

            appendAndSort(savedLocation)
            print("✅ Added location: \(name)")
            return .success
        } catch {
            print("🌊 Geocoding failed - likely ocean or invalid location: \(error.localizedDescription)")
            return .failed
        }
    }
    
    // MARK: - Search

    nonisolated func searchLocations(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        // 1) Check if it's a valid country name
        if let code = CountryData.countryNameToCode[trimmed.lowercased()] {
            let tzs = CountryData.timeZones(for: code)
            let locale = NSLocale(localeIdentifier: "en_US")
            let countryName = locale.displayName(forKey: .countryCode, value: code) ?? trimmed

            if tzs.isEmpty {
                // Single-timezone country not in our multi-zone map — geocode on selection
                return [SearchResult(
                    name: countryName,
                    subtitle: "",
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    timeZone: TimeZone.current
                )]
            }

            // Single timezone country — return directly, no picker needed
            if tzs.count == 1, let tz = tzs.first {
                let components = tz.identifier.split(separator: "/")
                let cityName = components.count >= 2
                    ? String(components.last!).replacingOccurrences(of: "_", with: " ")
                    : tz.identifier
                return [SearchResult(
                    name: cityName,
                    subtitle: countryName,
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    timeZone: tz
                )]
            }

            return tzs.map { tz in
                let components = tz.identifier.split(separator: "/")
                let cityName = components.count >= 2
                    ? String(components.last!).replacingOccurrences(of: "_", with: " ")
                    : tz.identifier

                let seconds = tz.secondsFromGMT()
                let hours = seconds / 3600
                let mins = abs(seconds % 3600) / 60
                let offsetStr = mins > 0
                    ? String(format: "UTC%+d:%02d", hours, mins)
                    : String(format: "UTC%+d", hours)

                return SearchResult(
                    name: cityName,
                    subtitle: "\(countryName) · \(offsetStr)",
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    timeZone: tz
                )
            }
        }

        // 2) Check if it's a capital city
        if let capitalCountryCode = CountryData.capitalCities[trimmed.lowercased()] {
            let locale = NSLocale(localeIdentifier: "en_US")
            let countryName = locale.displayName(forKey: .countryCode, value: capitalCountryCode) ?? ""
            return [SearchResult(
                name: trimmed.capitalized,
                subtitle: countryName,
                coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                timeZone: TimeZone.current
            )]
        }

        // 3) Not recognised
        return []
    }

    func addLocation(from searchResult: SearchResult) async -> (coordinate: CLLocationCoordinate2D?, result: AddLocationResult) {
        guard savedLocations.count < 10 else {
            buzzError()
            return (nil, .limitReached)
        }

        // Geocode the city name to get an accurate coordinate for the pin
        var coordinate = searchResult.coordinate
        let geocodeQuery = searchResult.name
        if coordinate.latitude == 0 && coordinate.longitude == 0 {
            if let request = MKGeocodingRequest(addressString: geocodeQuery) {
                if let mapItems = try? await request.mapItems, let item = mapItems.first {
                    coordinate = item.location.coordinate
                    // For capital cities, also pick up the correct timezone from geocoding
                    if searchResult.timeZone == TimeZone.current,
                       let resolvedTZ = item.timeZone {
                        // Check for duplicate timezone
                        if hasTimeZone(resolvedTZ) {
                            buzzError()
                            return (nil, .duplicate)
                        }
                        // Use placemark country if available, otherwise look up from our data
                        let city = resolvedTZ.identifier.split(separator: "/").last
                            .map { String($0).replacingOccurrences(of: "_", with: " ") }
                            ?? resolvedTZ.identifier
                        let friendlyName: String
                        if let country = item.placemark.country {
                            friendlyName = "\(country)/\(city)"
                        } else {
                            friendlyName = CountryData.friendlyName(for: resolvedTZ.identifier)
                        }
                        let savedLocation = SavedLocation(
                            coordinate: coordinate,
                            timeZone: resolvedTZ,
                            locationName: friendlyName
                        )
                        appendAndSort(savedLocation)
                        print("✅ Added location: \(searchResult.name) (\(resolvedTZ.identifier))")
                        return (coordinate, .success)
                    }
                }
            }
        }

        // Check for duplicate timezone
        if hasTimeZone(searchResult.timeZone) {
            buzzError()
            return (nil, .duplicate)
        }

        let savedLocation = SavedLocation(
            coordinate: coordinate,
            timeZone: searchResult.timeZone,
            locationName: CountryData.friendlyName(for: searchResult.timeZone.identifier)
        )

        appendAndSort(savedLocation)
        print("✅ Added location: \(searchResult.name) (\(searchResult.timeZone.identifier))")
        return (coordinate, .success)
    }

    func addLocation(bySearching query: String) async -> (coordinate: CLLocationCoordinate2D?, result: AddLocationResult) {
        guard savedLocations.count < 10 else {
            buzzError()
            return (nil, .limitReached)
        }
        guard !query.isEmpty else { return (nil, .failed) }

        // First, try to find it as a timezone identifier
        if let timeZone = TimeZone(identifier: query) {
            if hasTimeZone(timeZone) {
                buzzError()
                return (nil, .duplicate)
            }
            let coord = await addLocationForTimeZone(timeZone, name: query)
            return (coord, coord != nil ? .success : .failed)
        }

        // Otherwise, geocode the query as a place name using MapKit
        guard let request = MKGeocodingRequest(addressString: query) else {
            return (nil, .failed)
        }

        do {
            let mapItems = try await request.mapItems

            if let firstItem = mapItems.first {
                let coordinate = firstItem.location.coordinate
                let timeZone = firstItem.timeZone ?? TimeZone.current

                if hasTimeZone(timeZone) {
                    buzzError()
                    return (nil, .duplicate)
                }

                // Build friendly name using placemark country if available
                let city = timeZone.identifier.split(separator: "/").last
                    .map { String($0).replacingOccurrences(of: "_", with: " ") }
                    ?? timeZone.identifier
                let name: String
                if let country = firstItem.placemark.country {
                    name = "\(country)/\(city)"
                } else {
                    name = CountryData.friendlyName(for: timeZone.identifier)
                }

                let savedLocation = SavedLocation(
                    coordinate: coordinate,
                    timeZone: timeZone,
                    locationName: name
                )

                appendAndSort(savedLocation)
                return (coordinate, .success)
            }
        } catch {
            print("Geocoding failed for query '\(query)': \(error.localizedDescription)")
        }

        return (nil, .failed)
    }
    
    private func addLocationForTimeZone(_ timeZone: TimeZone, name: String) async -> CLLocationCoordinate2D? {
        let friendlyName = CountryData.friendlyName(for: timeZone.identifier)
        let coordinate: CLLocationCoordinate2D

        // Try to extract city from timezone identifier (e.g., "America/New_York" -> "New York")
        let components = timeZone.identifier.split(separator: "/")
        if components.count >= 2 {
            let cityName = components[1].replacingOccurrences(of: "_", with: " ")

            // Try to geocode the city name using MapKit
            guard let request = MKGeocodingRequest(addressString: String(cityName)) else {
                coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)

                let savedLocation = SavedLocation(
                    coordinate: coordinate,
                    timeZone: timeZone,
                    locationName: friendlyName
                )

                appendAndSort(savedLocation)
                return coordinate
            }

            do {
                let mapItems = try await request.mapItems
                if let firstItem = mapItems.first {
                    coordinate = firstItem.location.coordinate

                    // Use placemark country if available for even better accuracy
                    let finalName: String
                    if let country = firstItem.placemark.country {
                        let city = timeZone.identifier.split(separator: "/").last
                            .map { String($0).replacingOccurrences(of: "_", with: " ") }
                            ?? timeZone.identifier
                        finalName = "\(country)/\(city)"
                    } else {
                        finalName = friendlyName
                    }

                    let savedLocation = SavedLocation(
                        coordinate: coordinate,
                        timeZone: timeZone,
                        locationName: finalName
                    )

                    appendAndSort(savedLocation)
                    return coordinate
                }
            } catch {
                // Fall through to default coordinate
            }
        }

        // Fallback: use a default coordinate (0, 0) if we can't determine location
        coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        let savedLocation = SavedLocation(
            coordinate: coordinate,
            timeZone: timeZone,
            locationName: friendlyName
        )

        appendAndSort(savedLocation)
        return coordinate
    }

    func removeLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }
    }
    
    // MARK: - Cache Management
    private func cacheGeocoding(key: String, coordinate: CLLocationCoordinate2D, timeZone: TimeZone) {
        geocodingCache[key] = (coordinate, timeZone)
        // Limit cache size to prevent unbounded growth
        if geocodingCache.count > maxCacheSize {
            // Remove oldest entries (simple strategy: remove first few)
            let keysToRemove = Array(geocodingCache.keys.prefix(10))
            keysToRemove.forEach { geocodingCache.removeValue(forKey: $0) }
        }
    }
    
    func clearCache() {
        geocodingCache.removeAll()
    }
    
    func toggleLock(for locationId: UUID) {
        if let index = savedLocations.firstIndex(where: { $0.id == locationId }) {
            savedLocations[index].isLocked.toggle()
        }
    }
    
    // Helper function to format location names from timezone identifiers
    private func formatLocationName(from identifier: String) -> String {
        // Split by "/" and take the last component (e.g., "Europe/Paris" -> "Paris")
        let components = identifier.split(separator: "/")
        
        if let cityPart = components.last {
            // Replace underscores with spaces (e.g., "New_York" -> "New York")
            return cityPart.replacingOccurrences(of: "_", with: " ")
        }
        
        return identifier
    }
    
    func updateLocationCoordinate(id: UUID, newCoordinate: CLLocationCoordinate2D) async {
        guard savedLocations.contains(where: { $0.id == id }) else { return }

        // Reverse geocode the new location to update timezone and name
        let location = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
        
        guard let request = MKReverseGeocodingRequest(location: location) else {
            // Geocoding unavailable — just update the coordinate in place
            if let index = savedLocations.firstIndex(where: { $0.id == id }) {
                savedLocations[index].coordinate = newCoordinate
            }
            return
        }

        do {
            let mapItems = try await request.mapItems

            if let firstItem = mapItems.first {
                let timeZone = firstItem.timeZone ?? TimeZone.current

                // Build friendly name
                let city = timeZone.identifier.split(separator: "/").last
                    .map { String($0).replacingOccurrences(of: "_", with: " ") }
                    ?? timeZone.identifier
                let name: String
                if let country = firstItem.placemark.country {
                    name = "\(country)/\(city)"
                } else {
                    name = CountryData.friendlyName(for: timeZone.identifier)
                }

                // Update the existing location while preserving the ID, then re-sort
                if let index = savedLocations.firstIndex(where: { $0.id == id }) {
                    var updated = savedLocations
                    updated[index] = SavedLocation(
                        id: id, // Preserve the original ID
                        coordinate: newCoordinate,
                        timeZone: timeZone,
                        locationName: name
                    )
                    savedLocations = locationsSortedByTime(updated)
                }
            } else {
                // No map item — just update coordinate
                if let index = savedLocations.firstIndex(where: { $0.id == id }) {
                    savedLocations[index].coordinate = newCoordinate
                }
            }
        } catch {
            // Geocoding failed — just update coordinate
            if let index = savedLocations.firstIndex(where: { $0.id == id }) {
                savedLocations[index].coordinate = newCoordinate
            }
            print("Failed to reverse geocode dragged location: \(error.localizedDescription)")
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Stop updates after getting the first fix — we only need the user's location once
        manager.stopUpdatingLocation()

        Task { @MainActor in
            self.userLocation = location.coordinate
            self.userTimeZone = TimeZone.current
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error.localizedDescription)")
        // Stop trying to avoid repeated errors
        Task { @MainActor in
            locationManager.stopUpdatingLocation()
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("🔐 Location authorization changed: \(status.rawValue)")
        
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
}
