//
//  TimesListView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct TimesListView: View {
    @ObservedObject var locationManager: LocationManager
    let onBack: () -> Void

    @AppStorage("selectedDateTimestamp") private var selectedDateTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("selectedLocationID") private var selectedLocationIDString: String = ""

    @StateObject private var meetingStorage = MeetingStorage()
    @AppStorage("currentMeetingID") private var currentMeetingIDString: String = ""
    private var currentMeetingID: UUID? {
        currentMeetingIDString.isEmpty ? nil : UUID(uuidString: currentMeetingIDString)
    }

    var selectedDate: Date {
        get { Date(timeIntervalSince1970: selectedDateTimestamp) }
        nonmutating set { selectedDateTimestamp = newValue.timeIntervalSince1970 }
    }

    var selectedLocationID: UUID? {
        selectedLocationIDString.isEmpty ? nil : UUID(uuidString: selectedLocationIDString)
    }

    var selectedTimeZone: TimeZone {
        if let selectedID = selectedLocationID,
           let location = locationManager.savedLocations.first(where: { $0.id == selectedID }) {
            return location.timeZone
        }
        return locationManager.userTimeZone
    }

    var selectedLocationName: String {
        if let selectedID = selectedLocationID,
           let location = locationManager.savedLocations.first(where: { $0.id == selectedID }) {
            return location.locationName
        }
        return "Your Location"
    }

    // Computed property to get sorted locations with selected one at top
    var sortedLocations: [SavedLocation] {
        guard let selectedID = selectedLocationID else {
            // No location selected - sort all by time zone offset
            return locationManager.savedLocations.sorted { location1, location2 in
                let offset1 = location1.timeZone.secondsFromGMT(for: selectedDate)
                let offset2 = location2.timeZone.secondsFromGMT(for: selectedDate)
                return offset1 < offset2
            }
        }

        var sorted = locationManager.savedLocations
        // Remove selected location
        if let selectedIndex = sorted.firstIndex(where: { $0.id == selectedID }) {
            let selectedLocation = sorted.remove(at: selectedIndex)

            // Sort remaining locations by time zone offset
            sorted.sort { location1, location2 in
                let offset1 = location1.timeZone.secondsFromGMT(for: selectedDate)
                let offset2 = location2.timeZone.secondsFromGMT(for: selectedDate)
                return offset1 < offset2
            }

            // Insert selected location at the top
            sorted.insert(selectedLocation, at: 0)
        }
        return sorted
    }

    @State private var showingClearConfirmation = false
    @State private var showingMeetingNamePrompt = false
    @AppStorage("meetingName") private var meetingName = ""
    @State private var showingSaveMeetingPrompt = false
    @State private var showingOpenMeeting = false
    @State private var savedScheduleText = ""
    @State private var isLoadingMeeting = false  // Guard to suppress auto-save during loadMeeting()
    @State private var autoSaveTask: Task<Void, Never>?  // Debounce timer for auto-save

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with meeting name, nav buttons
                VStack(spacing: 0) {
                    HStack {
                        Button(action: onBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Map")
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Active meeting name
                        if currentMeetingID != nil && !meetingName.isEmpty {
                            Text(meetingName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Meeting menu (Save, Open, Clear)
                        Menu {
                            Button(action: {
                                if currentMeetingID != nil {
                                    // Already tracking a meeting — just save in place
                                    autoSaveCurrentMeeting()
                                } else {
                                    // No active meeting — prompt for a name
                                    meetingName = ""
                                    showingMeetingNamePrompt = true
                                }
                            }) {
                                Label("Save", systemImage: "square.and.arrow.down")
                            }

                            Button(action: {
                                showingOpenMeeting = true
                            }) {
                                Label("Open", systemImage: "folder")
                            }
                            .disabled(meetingStorage.savedMeetings.isEmpty)

                            Divider()

                            Button(role: .destructive, action: {
                                showingClearConfirmation = true
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                            .disabled(locationManager.savedLocations.filter { !$0.isLocked }.isEmpty)
                        } label: {
                            Text("Menu")
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

//                    // Active meeting name indicator
//                    if currentMeetingID != nil && !meetingName.isEmpty {
//                        HStack(spacing: 6) {
//                            Image(systemName: "doc.fill")
//                                .font(.system(size: 11))
//                                .foregroundColor(.secondary)
//                            Text(meetingName)
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
//                                .lineLimit(1)
//                            Text("· auto-saving")
//                                .font(.caption2)
//                                .foregroundColor(.green)
//                        }
//                        .padding(.horizontal)
//                        .padding(.bottom, 8)
//                    }
                }
                .background(.ultraThinMaterial)

                // Interactive Calendar and Time Scrubber
                DraggableCalendarView(
                    selectedDate: Binding(
                        get: { self.selectedDate },
                        set: { self.selectedDate = $0 }
                    ),
                    timeZone: selectedTimeZone
                )

                Divider()

                // Scrollable list of locations
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 12) {
                            // User's location - shown first if selected, otherwise after selected saved location
                            if selectedLocationID == nil {
                                CompactTimeCard(
                                    title: "Your Location",
                                    timeZone: locationManager.userTimeZone,
                                    selectedDate: selectedDate,
                                    isUserLocation: true,
                                    isSelected: true,
                                    isLocked: false,
                                    locationId: nil,
                                    onDelete: nil,
                                    onTap: {
                                        selectedLocationIDString = ""
                                    },
                                    onToggleLock: nil
                                )
                                .padding(.horizontal, 16)
                                .id("your-location-selected")
                            }

                            // All saved locations in sorted order
                            ForEach(sortedLocations) { location in
                                CompactTimeCard(
                                    title: location.locationName,
                                    timeZone: location.timeZone,
                                    selectedDate: selectedDate,
                                    isUserLocation: false,
                                    isSelected: selectedLocationID == location.id,
                                    isLocked: location.isLocked,
                                    locationId: location.id,
                                    onDelete: {
                                        // If deleting the selected location, reset to user location
                                        if selectedLocationID == location.id {
                                            selectedLocationIDString = ""
                                        }
                                        // Delete with animation
                                        withAnimation {
                                            locationManager.removeLocation(location)
                                        }
                                    },
                                    onTap: {
                                        selectedLocationIDString = location.id.uuidString
                                    },
                                    onToggleLock: {
                                        locationManager.toggleLock(for: location.id)
                                    }
                                )
                                .padding(.horizontal, 16)
                                .id(location.id)
                            }

                            // User's location - shown after saved locations when not selected
                            if selectedLocationID != nil {
                                CompactTimeCard(
                                    title: "Your Location",
                                    timeZone: locationManager.userTimeZone,
                                    selectedDate: selectedDate,
                                    isUserLocation: true,
                                    isSelected: false,
                                    isLocked: false,
                                    locationId: nil,
                                    onDelete: nil,
                                    onTap: {
                                        selectedLocationIDString = ""
                                    },
                                    onToggleLock: nil
                                )
                                .padding(.horizontal, 16)
                                .id("your-location-unselected")
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.bottom, 80) // Add padding at bottom so content isn't hidden behind share button
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedLocationID)
                    }
                    .onChange(of: selectedLocationID) { _, _ in
                        // Scroll to top when selection changes
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo("list-top", anchor: .top)
                        }
                    }
                }
                .scrollDisabled(false)
                .onAppear {
                    // Validate that the selected location still exists
                    if let selectedID = selectedLocationID {
                        let locationExists = locationManager.savedLocations.contains { $0.id == selectedID }
                        if !locationExists {
                            // Reset to user location if saved location was deleted
                            selectedLocationIDString = ""
                        }
                    }
                }
            }

            // Share button floating at bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingSaveMeetingPrompt = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .persistentSystemOverlays(.hidden)
        .alert("Save Meeting", isPresented: $showingMeetingNamePrompt) {
            TextField("Enter meeting name", text: $meetingName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {
                meetingName = ""
            }
            Button("Save") {
                saveMeeting()
            }
            .disabled(meetingName.isEmpty)
        } message: {
            Text("Enter a name for this meeting.")
        }
        .alert("Share Schedule", isPresented: $showingSaveMeetingPrompt) {
            TextField("Enter meeting name", text: $meetingName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {
                meetingName = ""
            }
            Button("Share") {
                shareSchedule()
                meetingName = ""
            }
            .disabled(meetingName.isEmpty)
        } message: {
            Text("Enter a name for this meeting to share the schedule.")
        }
        .sheet(isPresented: $showingOpenMeeting) {
            OpenMeetingView(meetingStorage: meetingStorage, currentMeetingID: currentMeetingID, onSelectMeeting: { meeting in
                loadMeeting(meeting)
            })
        }
        .alert("Clear All Locations", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                // Dissociate from the active meeting (stop auto-saving)
                currentMeetingIDString = ""
                meetingName = ""

                // Clear only unlocked saved locations
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    locationManager.savedLocations.removeAll { !$0.isLocked }
                }

                // Reset to user location and current date/time
                selectedLocationIDString = ""
                selectedDate = Date()
            }
        } message: {
            let lockedCount = locationManager.savedLocations.filter { $0.isLocked }.count
            if lockedCount > 0 {
                return Text("This will remove all unlocked locations and reset to your current local date and time. \(lockedCount) locked location\(lockedCount == 1 ? "" : "s") will remain.")
            } else {
                return Text("This will remove all saved locations and reset to your current local date and time.")
            }
        }
        // MARK: - Auto-save triggers (debounced, guarded)
        .onChange(of: locationManager.savedLocations) { _, _ in
            scheduleAutoSave()
        }
        .onChange(of: selectedDateTimestamp) { _, _ in
            scheduleAutoSave()
        }
        .onChange(of: selectedLocationIDString) { _, _ in
            scheduleAutoSave()
        }
    }

    func shareSchedule() {
        // Create a formatted text schedule
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var scheduleText = ""

        // Add meeting name at the top
        if !meetingName.isEmpty {
            scheduleText += "\(meetingName)\n"
            scheduleText += String(repeating: "=", count: meetingName.count) + "\n\n"
        }

        // Add meeting location and time at the top
        formatter.timeZone = selectedTimeZone
        scheduleText += "Meeting time zone: \(selectedTimeZone.identifier.replacingOccurrences(of: "_", with: " "))\n"
        scheduleText += "Meeting time: \(formatter.string(from: selectedDate)) (local time)\n\n"

        scheduleText += "World Times Schedule\n\n"

        // Check if meeting location is the user's location
        let isMeetingAtUserLocation = selectedTimeZone.identifier == locationManager.userTimeZone.identifier

        // Add user location only if it's different from meeting location
        if !isMeetingAtUserLocation {
            formatter.timeZone = locationManager.userTimeZone
            scheduleText += "Your Location:\n"
            scheduleText += "\(formatter.string(from: selectedDate))\n"
            scheduleText += "\(locationManager.userTimeZone.identifier)\n\n"
        }

        // Add saved locations
        for location in locationManager.savedLocations {
            formatter.timeZone = location.timeZone
            scheduleText += "\(location.locationName):\n"
            scheduleText += "\(formatter.string(from: selectedDate))\n"

            // Calculate time difference
            let userOffset = TimeZone.current.secondsFromGMT(for: selectedDate)
            let targetOffset = location.timeZone.secondsFromGMT(for: selectedDate)
            let difference = (targetOffset - userOffset) / 3600

            if difference == 0 {
                scheduleText += "Same time as your location\n\n"
            } else if difference > 0 {
                scheduleText += "\(difference) hour\(abs(difference) == 1 ? "" : "s") ahead\n\n"
            } else {
                scheduleText += "\(abs(difference)) hour\(abs(difference) == 1 ? "" : "s") behind\n\n"
            }
        }

        // Share using UIActivityViewController
        let activityController = UIActivityViewController(
            activityItems: [scheduleText],
            applicationActivities: nil
        )

        // For iPad, set the source view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {

            // For iPad popover presentation
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.maxY - 100, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            rootVC.present(activityController, animated: true)
        }

        // After sharing, ask if they want to save
        savedScheduleText = scheduleText
        showingSaveMeetingPrompt = true
    }

    func saveMeeting() {
        let meeting = SavedMeeting(
            name: meetingName,
            locations: locationManager.savedLocations,
            selectedLocationID: selectedLocationIDString,
            dateTimestamp: selectedDateTimestamp
        )
        meetingStorage.saveMeeting(meeting)
        // Start tracking this new meeting for auto-save
        currentMeetingIDString = meeting.id.uuidString
    }

    /// Debounce auto-save: coalesces rapid changes (e.g. loadMeeting setting 3 properties) into one save
    func scheduleAutoSave() {
        guard !isLoadingMeeting else { return }  // Don't auto-save while restoring a meeting
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            autoSaveCurrentMeeting()
        }
    }

    /// Auto-save current state back to the active meeting (silent, no prompts)
    func autoSaveCurrentMeeting() {
        guard !isLoadingMeeting else { return }
        guard let id = currentMeetingID else { return }
        // Only auto-save if the meeting still exists in storage
        guard meetingStorage.savedMeetings.contains(where: { $0.id == id }) else {
            currentMeetingIDString = ""
            return
        }
        let meeting = SavedMeeting(
            id: id,
            name: meetingName,
            locations: locationManager.savedLocations,
            selectedLocationID: selectedLocationIDString,
            dateTimestamp: selectedDateTimestamp
        )
        meetingStorage.saveMeeting(meeting)
    }

    func loadMeeting(_ meeting: SavedMeeting) {
        // Suppress auto-save while restoring state (prevents recursive save loop)
        isLoadingMeeting = true

        // Track which meeting we're editing
        currentMeetingIDString = meeting.id.uuidString

        // Restore the locations (sorted by timezone offset)
        locationManager.setLocationsSorted(meeting.locations)

        // Restore the selected location
        if !meeting.selectedLocationID.isEmpty {
            if let selectedUUID = UUID(uuidString: meeting.selectedLocationID),
               meeting.locations.contains(where: { $0.id == selectedUUID }) {
                selectedLocationIDString = meeting.selectedLocationID
            } else {
                selectedLocationIDString = ""
            }
        } else {
            selectedLocationIDString = ""
        }

        // Restore the date
        selectedDate = Date(timeIntervalSince1970: meeting.dateTimestamp)

        // Restore the meeting name
        meetingName = meeting.name

        // Re-enable auto-save after state is fully restored
        isLoadingMeeting = false
    }
}
