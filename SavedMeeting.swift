//
//  SavedMeeting.swift
//  TapTime
//
//  Created by Gerry Orkin on 16/2/2026.
//

import Foundation
internal import Combine

struct SavedMeeting: Identifiable, Codable {
    var id: UUID
    var name: String
    var locations: [SavedLocation]  // Store the actual locations
    var selectedLocationID: String  // The meeting location (empty string for user location)
    var dateTimestamp: Double
    var createdAt: Double
    var modifiedAt: Double

    init(id: UUID = UUID(), name: String, locations: [SavedLocation], selectedLocationID: String, dateTimestamp: Double, createdAt: Double = Date().timeIntervalSince1970, modifiedAt: Double = Date().timeIntervalSince1970) {
        self.id = id
        self.name = name
        self.locations = locations
        self.selectedLocationID = selectedLocationID
        self.dateTimestamp = dateTimestamp
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// Codable init with backward compatibility for meetings saved without timestamps
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        locations = try container.decode([SavedLocation].self, forKey: .locations)
        selectedLocationID = try container.decode(String.self, forKey: .selectedLocationID)
        dateTimestamp = try container.decode(Double.self, forKey: .dateTimestamp)
        createdAt = try container.decodeIfPresent(Double.self, forKey: .createdAt) ?? dateTimestamp
        modifiedAt = try container.decodeIfPresent(Double.self, forKey: .modifiedAt) ?? dateTimestamp
    }
}

class MeetingStorage: ObservableObject {
    @Published var savedMeetings: [SavedMeeting] = []
    
    private let meetingsKey = "savedMeetings"
    
    init() {
        loadMeetings()
    }
    
    func saveMeeting(_ meeting: SavedMeeting) {
        var updated = meeting
        updated.modifiedAt = Date().timeIntervalSince1970
        if let index = savedMeetings.firstIndex(where: { $0.id == updated.id }) {
            // Preserve original creation date
            updated.createdAt = savedMeetings[index].createdAt
            savedMeetings[index] = updated
        } else {
            savedMeetings.append(updated)
        }
        persistMeetings()
    }
    
    func deleteMeeting(_ meeting: SavedMeeting) {
        savedMeetings.removeAll { $0.id == meeting.id }
        persistMeetings()
    }
    
    private func persistMeetings() {
        if let encoded = try? JSONEncoder().encode(savedMeetings) {
            UserDefaults.standard.set(encoded, forKey: meetingsKey)
        }
    }
    
    private func loadMeetings() {
        if let data = UserDefaults.standard.data(forKey: meetingsKey),
           let decoded = try? JSONDecoder().decode([SavedMeeting].self, from: data) {
            savedMeetings = decoded
        }
    }
}
