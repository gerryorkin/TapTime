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
        return "Your location"
    }

    // Computed property to get sorted locations.
    // "byLocalTime": sort by UTC offset, selected at top.
    // "manual": return saved order as-is (drag-and-drop reorders this).
    var sortedLocations: [SavedLocation] {
        if locationSortMode == "manual" {
            return locationManager.savedLocations
        }

        // byLocalTime: sort by UTC offset, with selected location at top
        guard let selectedID = selectedLocationID else {
            return locationManager.savedLocations.sorted { location1, location2 in
                let offset1 = location1.timeZone.secondsFromGMT(for: selectedDate)
                let offset2 = location2.timeZone.secondsFromGMT(for: selectedDate)
                return offset1 < offset2
            }
        }

        var sorted = locationManager.savedLocations
        if let selectedIndex = sorted.firstIndex(where: { $0.id == selectedID }) {
            let selectedLocation = sorted.remove(at: selectedIndex)
            sorted.sort { location1, location2 in
                let offset1 = location1.timeZone.secondsFromGMT(for: selectedDate)
                let offset2 = location2.timeZone.secondsFromGMT(for: selectedDate)
                return offset1 < offset2
            }
            sorted.insert(selectedLocation, at: 0)
        }
        return sorted
    }

    // Number of locations that can actually be reordered (not anchored, not locked)
    var reorderableCount: Int {
        sortedLocations.filter { !$0.isLocked && $0.id != selectedLocationID }.count
    }

    @AppStorage("locationSortMode") private var locationSortMode: String = "byLocalTime"
    @State private var listEditMode: EditMode = .inactive
    @AppStorage("showingCalendar") private var showingCalendar = false
    @State private var showingClearConfirmation = false
    @State private var showingSharePrompt = false
    @AppStorage("meetingName") private var meetingName = ""

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with meeting name, nav buttons
                VStack(spacing: 0) {
                    ZStack {
                        VStack(spacing: 1) {
                            Text("Meeting time zone:")
                                .font(.caption)
                                .foregroundColor(.pink)
                            Text(selectedTimeZone.identifier.replacingOccurrences(of: "_", with: " "))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.pink)
                        }

                        HStack {
                        Button(action: onBack) {
                            Image(systemName: "map")
                                .font(.system(size: 32))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Sort order menu
                        Menu {
                            Button(action: {
                                locationSortMode = "byLocalTime"
                                listEditMode = .inactive
                                locationManager.reorderByLocalTime()
                            }) {
                                Label("Sort by Local Times", systemImage: "clock.arrow.2.circlepath")
                                if locationSortMode == "byLocalTime" { Image(systemName: "checkmark") }
                            }
                            Button(action: {
                                locationSortMode = "manual"
                                listEditMode = .active
                                if let id = selectedLocationID {
                                    locationManager.moveToFront(id)
                                }
                            }) {
                                Label("Manual Order", systemImage: "hand.draw.fill")
                                if locationSortMode == "manual" { Image(systemName: "checkmark") }
                            }
                        } label: {
                            Image(systemName: locationSortMode == "manual" ? "arrow.up.arrow.down.circle" : "arrow.up.arrow.down.circle.fill")
                                .font(.system(size: 32))
                        }
                        .buttonStyle(.plain)

                        // Clear all button
                        Button(action: {
                            showingClearConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 32))
                        }
                        .buttonStyle(.plain)
                        .disabled(locationManager.savedLocations.filter { !$0.isLocked }.isEmpty)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .background(.ultraThinMaterial)

                // Calendar (hidden by default, toggled by button)
                if showingCalendar {
                    DraggableCalendarView(
                        selectedDate: Binding(
                            get: { self.selectedDate },
                            set: { self.selectedDate = $0 }
                        ),
                        timeZone: selectedTimeZone
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Divider()
                }

                // Scrollable list of locations
                ScrollViewReader { scrollProxy in
                    List {
                        // User's location — shown first when nothing is selected
                        if selectedLocationID == nil {
                            CompactTimeCard(
                                title: "Your location",
                                timeZone: locationManager.userTimeZone,
                                selectedDate: selectedDate,
                                isUserLocation: true,
                                isSelected: true,
                                isLocked: false,
                                locationId: nil,
                                coordinate: locationManager.userLocation,
                                onDelete: nil,
                                onTap: {
                                    selectedLocationIDString = ""
                                    selectedDate = Date()
                                },
                                onToggleLock: nil
                            )
                            .padding(.horizontal, 16)
                            .id("your-location-selected")
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                        }

                        // All saved locations
                        ForEach(sortedLocations) { location in
                            CompactTimeCard(
                                title: location.locationName,
                                timeZone: location.timeZone,
                                selectedDate: selectedDate,
                                isUserLocation: false,
                                isSelected: selectedLocationID == location.id,
                                isLocked: location.isLocked,
                                locationId: location.id,
                                coordinate: location.coordinate,
                                onDelete: {
                                    if selectedLocationID == location.id {
                                        selectedLocationIDString = ""
                                    }
                                    withAnimation {
                                        locationManager.removeLocation(location)
                                    }
                                },
                                onTap: {
                                    selectedLocationIDString = location.id.uuidString
                                    selectedDate = Date()
                                },
                                onToggleLock: {
                                    locationManager.toggleLock(for: location.id)
                                }
                            )
                            .compositingGroup()
                            .padding(.horizontal, 16)
                            .id(location.id)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .moveDisabled(location.isLocked || selectedLocationID == location.id || reorderableCount < 2)
                            .deleteDisabled(true)
                        }
                        .onMove(perform: locationSortMode == "manual" ? { source, destination in
                            // minDestination=1 guards the anchor row at index 0
                            let minDest = selectedLocationID != nil ? 1 : 0
                            locationManager.moveLocations(from: source, to: destination, minDestination: minDest)
                        } : nil)

                        // User's location — shown after saved locations when one is selected
                        if selectedLocationID != nil {
                            CompactTimeCard(
                                title: "Your location",
                                timeZone: locationManager.userTimeZone,
                                selectedDate: selectedDate,
                                isUserLocation: true,
                                isSelected: false,
                                isLocked: false,
                                locationId: nil,
                                coordinate: locationManager.userLocation,
                                onDelete: nil,
                                onTap: {
                                    selectedLocationIDString = ""
                                    selectedDate = Date()
                                },
                                onToggleLock: nil
                            )
                            .padding(.horizontal, 16)
                            .id("your-location-unselected")
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                        }
                    }
                    .listRowSpacing(12)
                    .contentMargins(.top, 8)
                    .listStyle(.plain)
                    .environment(\.editMode, $listEditMode)
                    // Only animate row reordering in byLocalTime mode; in manual mode the
                    // native drag-to-reorder animation handles it and extra animation causes revert.
                    .animation(locationSortMode == "byLocalTime" ? .spring(response: 0.5, dampingFraction: 0.8) : nil, value: sortedLocations.map { $0.id })
                    .onAppear {
                        listEditMode = locationSortMode == "manual" ? .active : .inactive
                        // Ensure the anchor is at position 0 if we launch into manual mode
                        if locationSortMode == "manual", let id = selectedLocationID {
                            locationManager.moveToFront(id)
                        }
                    }
                    .onChange(of: locationSortMode) { _, newValue in
                        listEditMode = newValue == "manual" ? .active : .inactive
                        // Move newly-anchored selection to front when switching to manual
                        if newValue == "manual", let id = selectedLocationID {
                            locationManager.moveToFront(id)
                        }
                    }
                    .onChange(of: selectedLocationID) { _, newID in
                        if locationSortMode == "manual" {
                            // New selection becomes anchor at position 0
                            if let id = newID {
                                locationManager.moveToFront(id)
                            }
                        } else {
                            if let firstID = sortedLocations.first?.id {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollProxy.scrollTo(firstID, anchor: .top)
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    if let selectedID = selectedLocationID {
                        let locationExists = locationManager.savedLocations.contains { $0.id == selectedID }
                        if !locationExists {
                            selectedLocationIDString = ""
                        }
                    }
                }

                Divider()

                // Bottom bar: calendar toggle, time scrubber, share button
                HStack(spacing: 12) {
                    // Calendar toggle button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingCalendar.toggle()
                        }
                    }) {
                        Image(systemName: showingCalendar ? "calendar" : "calendar")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    // Time scrubber
                    TimeScrubberView(
                        selectedDate: Binding(
                            get: { self.selectedDate },
                            set: { self.selectedDate = $0 }
                        ),
                        timeZone: selectedTimeZone
                    )

                    // Share button
                    Button(action: {
                        showingSharePrompt = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemBackground))
            }
        }
        .persistentSystemOverlays(.hidden)
        .alert("Share Schedule", isPresented: $showingSharePrompt) {
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
        .alert("Clear All Locations", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
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

    }
}
