//
//  OpenMeetingView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct OpenMeetingView: View {
    @ObservedObject var meetingStorage: MeetingStorage
    let currentMeetingID: UUID?
    let onSelectMeeting: (SavedMeeting) -> Void
    @Environment(\.dismiss) private var dismiss

    private var sortedMeetings: [SavedMeeting] {
        meetingStorage.savedMeetings.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var body: some View {
        NavigationView {
            Group {
                if meetingStorage.savedMeetings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Saved Meetings")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Save a meeting first using the Save option in the menu.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sortedMeetings) { meeting in
                            Button(action: {
                                onSelectMeeting(meeting)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(meeting.name)
                                                .font(.headline)
                                            if meeting.id == currentMeetingID {
                                                Text("Active")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.15))
                                                    .cornerRadius(4)
                                            }
                                        }

                                        HStack(spacing: 12) {
                                            // Meeting date
                                            Label {
                                                Text(Date(timeIntervalSince1970: meeting.dateTimestamp), style: .date)
                                                    .font(.caption)
                                            } icon: {
                                                Image(systemName: "calendar")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.secondary)

                                            // Location count
                                            Label {
                                                Text("\(meeting.locations.count) location\(meeting.locations.count == 1 ? "" : "s")")
                                                    .font(.caption)
                                            } icon: {
                                                Image(systemName: "mappin")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(.secondary)
                                        }

                                        // Last modified
                                        Text("Modified \(Date(timeIntervalSince1970: meeting.modifiedAt), style: .relative) ago")
                                            .font(.caption2)
                                            .foregroundColor(.secondary.opacity(0.7))
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            let meetings = sortedMeetings
                            for index in indexSet {
                                meetingStorage.deleteMeeting(meetings[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Open Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if !meetingStorage.savedMeetings.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
        }
    }
}
