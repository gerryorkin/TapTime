//
//  LocationData.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import Foundation
import MapKit

struct SavedLocation: Identifiable, Equatable, Codable {
    var id: UUID // Changed from let to var to allow preservation
    var coordinate: CLLocationCoordinate2D // Changed to var to allow updates
    var timeZone: TimeZone // Changed to var to allow updates
    var locationName: String // Changed to var to allow updates
    
    // Default initializer that generates a new ID
    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, timeZone: TimeZone, locationName: String) {
        self.id = id
        self.coordinate = coordinate
        self.timeZone = timeZone
        self.locationName = locationName
    }
    
    // Computed property that always shows current time
    var displayName: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let currentTime = formatter.string(from: Date())
        let timeZoneAbbreviation = timeZone.abbreviation() ?? timeZone.identifier
        
        return "\(timeZoneAbbreviation) • \(currentTime)"
    }
    
    static func == (lhs: SavedLocation, rhs: SavedLocation) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, timeZoneIdentifier, locationName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let timeZoneIdentifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
        timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        locationName = try container.decode(String.self, forKey: .locationName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(timeZone.identifier, forKey: .timeZoneIdentifier)
        try container.encode(locationName, forKey: .locationName)
    }
}
