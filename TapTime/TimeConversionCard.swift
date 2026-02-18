//
//  TimeConversionCard.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct TimeConversionCard: View {
    let title: String
    let timeZone: TimeZone
    let selectedDate: Date
    let isUserLocation: Bool
    let onDelete: (() -> Void)?

    var convertedDate: Date {
        // Convert the selected date from user's timezone to this timezone
        selectedDate
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(timeZone.identifier)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Date
                Text(formattedDate())
                    .font(.headline)
                    .foregroundColor(.secondary)

                // Time
                Text(formattedTime())
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()

                // Time difference from user's timezone
                if !isUserLocation {
                    Text(timeDifference())
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(isUserLocation ? Color.blue.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }

    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: selectedDate)
    }

    private func timeDifference() -> String {
        // Calculate offset difference in hours
        let userOffset = TimeZone.current.secondsFromGMT(for: selectedDate)
        let targetOffset = timeZone.secondsFromGMT(for: selectedDate)
        let difference = (targetOffset - userOffset) / 3600

        if difference == 0 {
            return "Same time as your location"
        } else if difference > 0 {
            return "\(difference) hour\(abs(difference) == 1 ? "" : "s") ahead"
        } else {
            return "\(abs(difference)) hour\(abs(difference) == 1 ? "" : "s") behind"
        }
    }
}
