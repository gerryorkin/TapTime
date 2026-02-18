//
//  HelpView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hosting a meeting and want to tell people in multiple locations what time it starts?")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        helpStep(number: "1", text: "Tap to place a location marker for each person you are inviting to attend. Just tap the country they live in on the map, or use the search feature. You don't need to do that for you and your location, unless you are currently in a time zone that is different from where you'll be when the meeting happens.")

                        helpStep(number: "2", text: "Tap the Choose Date and Time button.")

                        helpStep(number: "3", text: "Tap on the calendar to choose the day your meeting will occur, in your local time.")

                        helpStep(number: "4", text: "Drag the time setting control to set the time for your meeting.")

                        helpStep(number: "5", text: "Done! You can share the list of dates and times with others by tapping the Share Schedule button.")

                        helpStep(number: "6", text: "If you are using the app to help someone else work out times for their meeting, make sure you have added their location on the map. Then, before you set the date and time the meeting will occur, tap on their location in the list on the calendar screen.")

                        helpStep(number: "7", text: "You can save meeting times, and open them next time you need to check the time you need to get online for that meeting. If you make changes (like changing the meeting time) they are automatically saved for you.")
                    }
                }
                .padding()
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func helpStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
