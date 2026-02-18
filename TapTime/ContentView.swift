//
//  ContentView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI
import MapKit
internal import Combine

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @AppStorage("showingTimesList") private var showingTimesList = false
    
    var body: some View {
        ZStack {
            // Keep MapSelectionView always in memory to prevent redrawing
            MapSelectionView(
                locationManager: locationManager,
                onDone: {
                    if !locationManager.savedLocations.isEmpty {
                        showingTimesList = true
                    }
                },
                onShowTimes: {
                    showingTimesList = true
                }
            )
            .opacity(showingTimesList ? 0 : 1)
            .allowsHitTesting(!showingTimesList)
            
            // Show TimesListView on top when needed
            if showingTimesList {
                TimesListView(
                    locationManager: locationManager,
                    onBack: {
                        showingTimesList = false
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingTimesList)
    }
}

// MARK: - Country Data
struct CountryLabel: Hashable {
    let name: String
    let coordinate: CLLocationCoordinate2D
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: CountryLabel, rhs: CountryLabel) -> Bool {
        lhs.name == rhs.name
    }
}

// Major countries with approximate center coordinates
let majorCountries: [CountryLabel] = [
    CountryLabel(name: "USA", coordinate: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5)),
    CountryLabel(name: "Canada", coordinate: CLLocationCoordinate2D(latitude: 56.1, longitude: -106.3)),
    CountryLabel(name: "Mexico", coordinate: CLLocationCoordinate2D(latitude: 23.6, longitude: -102.5)),
    CountryLabel(name: "Brazil", coordinate: CLLocationCoordinate2D(latitude: -14.2, longitude: -51.9)),
    CountryLabel(name: "Argentina", coordinate: CLLocationCoordinate2D(latitude: -38.4, longitude: -63.6)),
    CountryLabel(name: "UK", coordinate: CLLocationCoordinate2D(latitude: 55.3, longitude: -3.4)),
    CountryLabel(name: "France", coordinate: CLLocationCoordinate2D(latitude: 46.2, longitude: 2.2)),
    CountryLabel(name: "Germany", coordinate: CLLocationCoordinate2D(latitude: 51.1, longitude: 10.4)),
    CountryLabel(name: "Spain", coordinate: CLLocationCoordinate2D(latitude: 40.4, longitude: -3.7)),
    CountryLabel(name: "Italy", coordinate: CLLocationCoordinate2D(latitude: 41.8, longitude: 12.5)),
    CountryLabel(name: "Russia", coordinate: CLLocationCoordinate2D(latitude: 61.5, longitude: 105.3)),
    CountryLabel(name: "China", coordinate: CLLocationCoordinate2D(latitude: 35.8, longitude: 104.1)),
    CountryLabel(name: "India", coordinate: CLLocationCoordinate2D(latitude: 20.5, longitude: 78.9)),
    CountryLabel(name: "Japan", coordinate: CLLocationCoordinate2D(latitude: 36.2, longitude: 138.2)),
    CountryLabel(name: "Australia", coordinate: CLLocationCoordinate2D(latitude: -25.2, longitude: 133.7)),
    CountryLabel(name: "South Africa", coordinate: CLLocationCoordinate2D(latitude: -30.5, longitude: 22.9)),
    CountryLabel(name: "Egypt", coordinate: CLLocationCoordinate2D(latitude: 26.8, longitude: 30.8)),
    CountryLabel(name: "Saudi Arabia", coordinate: CLLocationCoordinate2D(latitude: 23.8, longitude: 45.0)),
    CountryLabel(name: "Turkey", coordinate: CLLocationCoordinate2D(latitude: 38.9, longitude: 35.2)),
    CountryLabel(name: "Indonesia", coordinate: CLLocationCoordinate2D(latitude: -0.7, longitude: 113.9)),
    CountryLabel(name: "Thailand", coordinate: CLLocationCoordinate2D(latitude: 15.8, longitude: 100.9)),
    CountryLabel(name: "South Korea", coordinate: CLLocationCoordinate2D(latitude: 35.9, longitude: 127.7)),
    CountryLabel(name: "New Zealand", coordinate: CLLocationCoordinate2D(latitude: -40.9, longitude: 174.8)),
    CountryLabel(name: "Chile", coordinate: CLLocationCoordinate2D(latitude: -35.6, longitude: -71.5)),
    CountryLabel(name: "Peru", coordinate: CLLocationCoordinate2D(latitude: -9.1, longitude: -75.0)),
    CountryLabel(name: "Colombia", coordinate: CLLocationCoordinate2D(latitude: 4.5, longitude: -74.2)),
    CountryLabel(name: "Nigeria", coordinate: CLLocationCoordinate2D(latitude: 9.0, longitude: 8.6)),
    CountryLabel(name: "Kenya", coordinate: CLLocationCoordinate2D(latitude: -0.0, longitude: 37.9)),
    CountryLabel(name: "Norway", coordinate: CLLocationCoordinate2D(latitude: 60.4, longitude: 8.4)),
    CountryLabel(name: "Sweden", coordinate: CLLocationCoordinate2D(latitude: 60.1, longitude: 18.6)),
    CountryLabel(name: "Poland", coordinate: CLLocationCoordinate2D(latitude: 51.9, longitude: 19.1)),
    CountryLabel(name: "Ukraine", coordinate: CLLocationCoordinate2D(latitude: 48.3, longitude: 31.1)),
    CountryLabel(name: "Iran", coordinate: CLLocationCoordinate2D(latitude: 32.4, longitude: 53.6)),
    CountryLabel(name: "Pakistan", coordinate: CLLocationCoordinate2D(latitude: 30.3, longitude: 69.3)),
    CountryLabel(name: "Vietnam", coordinate: CLLocationCoordinate2D(latitude: 14.0, longitude: 108.2)),
    CountryLabel(name: "Philippines", coordinate: CLLocationCoordinate2D(latitude: 12.8, longitude: 121.7)),
    CountryLabel(name: "Malaysia", coordinate: CLLocationCoordinate2D(latitude: 4.2, longitude: 101.9)),
    CountryLabel(name: "Afghanistan", coordinate: CLLocationCoordinate2D(latitude: 33.9, longitude: 67.7)),
    CountryLabel(name: "Morocco", coordinate: CLLocationCoordinate2D(latitude: 31.7, longitude: -7.0)),
    CountryLabel(name: "Algeria", coordinate: CLLocationCoordinate2D(latitude: 28.0, longitude: 1.6)),
]

// MARK: - Live Time Text
struct TimeText: View {
    let timeZone: TimeZone
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(formattedTime())
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: currentTime)
    }
}

// MARK: - Pulsing Dot Animation
struct PulsingDot: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .fill(.green.opacity(0.3))
                .frame(width: 24, height: 24)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 1)
            
            // Main dot
            Circle()
                .fill(.green)
                .frame(width: 24, height: 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Help View
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

// MARK: - Map Selection Screen
struct MapSelectionView: View {
    @ObservedObject var locationManager: LocationManager
    let onDone: () -> Void
    var onShowTimes: (() -> Void)? = nil
    
    @AppStorage("mapCenterLatitude") private var mapCenterLatitude: Double = 20.0
    @AppStorage("mapCenterLongitude") private var mapCenterLongitude: Double = 0.0
    @AppStorage("mapSpanLatitudeDelta") private var mapSpanLatitudeDelta: Double = 100.0
    @AppStorage("mapSpanLongitudeDelta") private var mapSpanLongitudeDelta: Double = 100.0
    @AppStorage("hasSetInitialMapPosition") private var hasSetInitialMapPosition = false
    
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)
    )
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [SearchResult] = []
    @State private var showingSearchResults = false
    @State private var showingInvalidCountry = false
    @State private var autocompleteSuggestion = ""
    @State private var hasSetInitialPosition = false
    @State private var mapCameraRegion: MKCoordinateRegion?
    @State private var showingSearchField = false
    @State private var showingSettings = false
    @State private var showingClearConfirmation = false
    @State private var showingOceanAlert = false
    @State private var showingDuplicateAlert = false
    @State private var showingHelp = false
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage("useLargePills") private var useLargePills = false

    var body: some View {
        ZStack(alignment: .top) {
            // Full screen map
            DraggableMapView(
                locationManager: locationManager,
                cameraPosition: $mapRegion,
                onTap: { coordinate in
                    Task {
                        let result = await locationManager.addLocation(at: coordinate)
                        if result == .duplicate {
                            showingDuplicateAlert = true
                        }
                    }
                },
                showTimezoneLines: false,
                showCountryLabels: (mapCameraRegion?.span.latitudeDelta ?? 100) > 30
            )
            .onAppear {
                // Restore saved map position
                if hasSetInitialMapPosition {
                    mapRegion = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: mapCenterLatitude,
                            longitude: mapCenterLongitude
                        ),
                        span: MKCoordinateSpan(
                            latitudeDelta: mapSpanLatitudeDelta,
                            longitudeDelta: mapSpanLongitudeDelta
                        )
                    )
                    hasSetInitialPosition = true
                } else if let userLocation = locationManager.userLocation {
                    // First time - use user location
                    mapRegion = MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
                    )
                    hasSetInitialPosition = true
                    hasSetInitialMapPosition = true
                }
            }
            .task {
                // Wait for user location and center the map when it becomes available (first launch only)
                if !hasSetInitialMapPosition {
                    for await _ in locationManager.$userLocation.values {
                        if let userLocation = locationManager.userLocation, !hasSetInitialPosition {
                            mapRegion = MKCoordinateRegion(
                                center: userLocation,
                                span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
                            )
                            hasSetInitialPosition = true
                            hasSetInitialMapPosition = true
                            break
                        }
                    }
                }
            }
            .onChange(of: mapRegion.center.latitude) { _, _ in
                saveMapPosition()
            }
            .onChange(of: mapRegion.center.longitude) { _, _ in
                saveMapPosition()
            }
            .onChange(of: mapRegion.span.latitudeDelta) { _, _ in
                saveMapPosition()
            }
            .onChange(of: mapRegion.span.longitudeDelta) { _, _ in
                saveMapPosition()
            }
            .ignoresSafeArea()

            // Buttons at top left — pill style matching location cards
            VStack {
                HStack {
                    VStack(spacing: -4) {
                        LeftPillButton(
                            icon: "questionmark.circle.fill",
                            label: "Help",
                            isLarge: useLargePills,
                            action: { showingHelp = true }
                        )

                        LeftPillButton(
                            icon: "gearshape.fill",
                            label: "Settings",
                            isLarge: useLargePills,
                            action: { showingSettings = true }
                        )
                        .padding(.top, useLargePills ? 0 : 12)

                        LeftPillButton(
                            icon: "xmark.circle.fill",
                            label: "Clear",
                            isLarge: useLargePills,
                            action: { showingClearConfirmation = true }
                        )
                        .padding(.top, useLargePills ? 0 : 12)
                        .disabled(locationManager.savedLocations.filter { !$0.isLocked }.isEmpty)
                        .opacity(locationManager.savedLocations.filter { !$0.isLocked }.isEmpty ? 0.5 : 1.0)
                    }
                    .frame(width: 200)

                    Spacer()
                }
                .padding(.top)

                Spacer()
            }

            // Location pills at the top right
            VStack {
                HStack {
                    Spacer()

                    VStack(spacing: -4) {
                        ForEach(locationManager.savedLocations) { location in
                            FloatingLocationCard(
                                location: location,
                                isLarge: useLargePills,
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        locationManager.removeLocation(location)
                                    }
                                },
                                onToggleLock: {
                                    locationManager.toggleLock(for: location.id)
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .offset(x: 194).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }

                        // Done button - appears below pills when there are locations
                        if !locationManager.savedLocations.isEmpty {
                            GeometryReader { geometry in
                                let cardWidth = geometry.size.width
                                let collapsedOffset = cardWidth * 0.45  // 45% off-screen (55% visible), matching pills

                                HStack(spacing: 6) {
                                    Text("Choose Date and Time")
                                        .font(.system(size: useLargePills ? 16 : 15))
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: useLargePills ? 12 : 10, weight: .bold))
                                    Spacer()
                                }
                                .padding(.horizontal, useLargePills ? 20 : 16)
                                .padding(.vertical, useLargePills ? 10 : 6)
                                .frame(width: cardWidth)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .clipShape(useLargePills ? AnyShape(RoundedRectangle(cornerRadius: 16)) : AnyShape(Capsule()))
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                .offset(x: collapsedOffset)
                                .onTapGesture {
                                    onDone()
                                }
                            }
                            .frame(height: useLargePills ? 44 : 32)
                            .padding(.top, 4)
                            .transition(.asymmetric(
                                insertion: .offset(x: 194).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: locationManager.savedLocations.map { $0.id })
                    .frame(width: 350)
                }
                .padding(.top)
                .padding(.trailing)

                Spacer()
            }

            // Search button floating on the map (bottom left)
            if !showingSearchField {
                VStack {
                    Spacer()
                    HStack {
                        LeftPillButton(
                            icon: "magnifyingglass",
                            label: "Search",
                            isLarge: useLargePills,
                            action: {
                                showingSearchField = true
                                isSearchFieldFocused = true
                            }
                        )
                        .frame(width: 200)
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
                .ignoresSafeArea(.keyboard)
            }

            // Search bar sitting just above the keyboard
            if showingSearchField {
                VStack(spacing: 0) {
                    Spacer()

                    // Search results (above the search bar)
                    if showingSearchResults && !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            // Cancel bar at top of results
                            HStack {
                                Text("Select a timezone")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Cancel") {
                                    searchText = ""
                                    searchResults = []
                                    showingSearchResults = false
                                    autocompleteSuggestion = ""
                                    isSearchFieldFocused = false
                                    showingSearchField = false
                                }
                                .font(.system(size: 15))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            Divider()

                            ForEach(searchResults) { result in
                                Button(action: {
                                    selectSearchResult(result)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.name)
                                                .font(.system(size: 17, weight: .medium))
                                                .foregroundColor(.primary)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text(result.timeZone.abbreviation() ?? "")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if result.id != searchResults.last?.id {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(uiColor: .systemBackground))
                    }

                    // Search field bar — matches keyboard background colour
                    // Only show the text field when results aren't displayed
                    if !showingSearchResults {
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))

                                TextField("Country or capital city", text: $searchText)
                                    .font(.system(size: 20))
                                    .textInputAutocapitalization(.words)
                                    .keyboardType(.default)
                                    .focused($isSearchFieldFocused)
                                    .submitLabel(.search)
                                    .onSubmit {
                                        if !autocompleteSuggestion.isEmpty {
                                            searchText = autocompleteSuggestion
                                            performSearch(query: autocompleteSuggestion)
                                        } else {
                                            performSearch()
                                        }
                                    }
                                    .onChange(of: searchText) { _, newValue in
                                        if newValue.isEmpty {
                                            searchResults = []
                                            showingSearchResults = false
                                            autocompleteSuggestion = ""
                                        } else {
                                            if let match = CountryData.autocomplete(prefix: newValue) {
                                                autocompleteSuggestion = match
                                            } else {
                                                autocompleteSuggestion = ""
                                            }
                                        }
                                    }

                                // Clear text button
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                        searchResults = []
                                        showingSearchResults = false
                                        autocompleteSuggestion = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button("Cancel") {
                                searchText = ""
                                searchResults = []
                                showingSearchResults = false
                                autocompleteSuggestion = ""
                                isSearchFieldFocused = false
                                showingSearchField = false
                            }
                            .font(.system(size: 17))
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .background(Color(uiColor: .systemGray5))
                        // Grey background extends behind the keyboard so there's no gap
                        .background(
                            Color(uiColor: .systemGray5)
                                .frame(height: 400)
                                .offset(y: 200) // Push it downward behind the keyboard
                                .ignoresSafeArea(.keyboard)
                        )
                    }
                }
            }
        }
        .onChange(of: isSearchFieldFocused) { _, focused in
            if !focused && showingSearchField && !showingInvalidCountry && !showingDuplicateAlert && !showingSearchResults {
                // Small delay to avoid racing with onSubmit or button taps
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Re-check conditions — focus may have returned or results may have appeared
                    if !isSearchFieldFocused && showingSearchField && !showingInvalidCountry && !showingDuplicateAlert && !showingSearchResults {
                        searchText = ""
                        searchResults = []
                        showingSearchResults = false
                        autocompleteSuggestion = ""
                        showingSearchField = false
                    }
                }
            }
        }
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $showingSettings) {
            SettingsView(useLargePills: $useLargePills)
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
        }
        .alert("Clear All Locations", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    locationManager.savedLocations.removeAll { !$0.isLocked }
                }
            }
        } message: {
            let lockedCount = locationManager.savedLocations.filter { $0.isLocked }.count
            if lockedCount > 0 {
                return Text("This will remove all unlocked locations. \(lockedCount) locked location\(lockedCount == 1 ? "" : "s") will remain.")
            } else {
                return Text("Are you sure you want to remove all saved locations?")
            }
        }
        .alert("Not Recognised", isPresented: $showingInvalidCountry) {
            Button("OK", role: .cancel) {
                // Re-focus the search field so keyboard reappears
                isSearchFieldFocused = true
            }
        } message: {
            Text("Please enter a valid country or capital city (e.g. Australia, Tokyo, United States).")
        }
        .alert("Already Added", isPresented: $showingDuplicateAlert) {
            Button("OK", role: .cancel) {
                // Re-focus the search field so keyboard reappears
                if showingSearchField {
                    isSearchFieldFocused = true
                }
            }
        } message: {
            Text("That timezone is already in your list.")
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
    }
    
    private func saveMapPosition() {
        mapCenterLatitude = mapRegion.center.latitude
        mapCenterLongitude = mapRegion.center.longitude
        mapSpanLatitudeDelta = mapRegion.span.latitudeDelta
        mapSpanLongitudeDelta = mapRegion.span.longitudeDelta
    }
    
    private func performSearch(query: String? = nil) {
        let searchQuery = query ?? searchText
        guard !searchQuery.isEmpty else { return }

        // searchLocations is synchronous — no network, just dictionary lookups
        let results = locationManager.searchLocations(query: searchQuery)

        if results.isEmpty {
            showingInvalidCountry = true
        } else if results.count == 1 {
            selectSearchResult(results[0])
        } else {
            searchResults = results
            withAnimation {
                showingSearchResults = true
            }
        }
    }

    private func selectSearchResult(_ result: SearchResult) {
        searchText = ""
        searchResults = []
        showingSearchResults = false
        autocompleteSuggestion = ""
        isSearchFieldFocused = false
        showingSearchField = false

        Task {
            let (coordinate, addResult) = await locationManager.addLocation(from: result)
            await MainActor.run {
                if addResult == .duplicate {
                    showingDuplicateAlert = true
                } else if let coordinate = coordinate {
                    withAnimation {
                        mapRegion = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Binding var useLargePills: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Use Larger Pills", isOn: $useLargePills)
                } header: {
                    Text("Display Options")
                } footer: {
                    Text("Show location cards with larger text and increased padding")
                }
                
                Section {
                    Text("Made by Gerry Orkin in beautiful Austinmer, New South Wales.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Left Pill Button (matches location card style)
struct LeftPillButton: View {
    let icon: String
    let label: String
    let isLarge: Bool
    let action: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let collapsedOffset = -(cardWidth * 0.70)  // 70% off-screen to the left (30% visible)

            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: isLarge ? 16 : 14))
            }
            .padding(.horizontal, isLarge ? 20 : 16)
            .padding(.vertical, isLarge ? 10 : 6)
            .frame(width: cardWidth)
            .background(
                Color.white.opacity(0.5)
                    .background(.ultraThinMaterial)
            )
            .foregroundColor(.black)
            .clipShape(isLarge ? AnyShape(RoundedRectangle(cornerRadius: 16)) : AnyShape(Capsule()))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .offset(x: collapsedOffset)
            .onTapGesture {
                action()
            }
        }
        .frame(height: isLarge ? 44 : 32)
    }
}

// MARK: - Floating Location Card
struct FloatingLocationCard: View {
    let location: SavedLocation
    let isLarge: Bool
    let onDelete: () -> Void
    let onToggleLock: () -> Void

    @State private var currentTime = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var isExpanded = false  // Start collapsed (55% visible)
    @GestureState private var isDragging = false
    @State private var backgroundOpacity: Double = 1.0  // Start white, fade to transparent
    @State private var showColon = true  // For flashing colon

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let collapsedOffset = cardWidth * 0.45  // 45% off-screen (55% visible)
            let expandedOffset: CGFloat = 0  // Fully visible
            
            Group {
                if isLarge {
                    // Large pills: Two-line layout with right-aligned time
                    HStack(spacing: 16) {
                        // Lock icon on the left - tappable
                        Button(action: onToggleLock) {
                            Image(systemName: location.isLocked ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(location.isLocked ? .orange : .gray.opacity(0.3))
                                .font(.system(size: 14))
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Line 1: Location name
                            Text(location.locationName)
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            // Line 2: Timezone abbreviation - only show when expanded
                            if isExpanded {
                                Text(location.timeZone.abbreviation() ?? location.timeZone.identifier)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .transition(.opacity)
                            }
                        }
                        
                        Spacer()
                        
                        // Right-aligned time
                        Text(formattedTime())
                            .font(.system(size: 18, design: .rounded))
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .opacity(showColon ? 1.0 : 0.3)
                        
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(location.isLocked ? .gray.opacity(0.3) : .red)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                        .disabled(location.isLocked)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(width: cardWidth)
                    .background(
                        ZStack {
                            // When expanded, show white background
                            // When collapsed, fade to more transparent material
                            if isExpanded {
                                Color.white
                            } else {
                                if backgroundOpacity > 0 {
                                    Color.white.opacity(backgroundOpacity)
                                }
                                if backgroundOpacity < 1.0 {
                                    Color.white.opacity(0.5)
                                        .background(.ultraThinMaterial)
                                }
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                } else {
                    // Small pills: Single-line layout
                    HStack(spacing: 12) {
                        // Lock icon on the left - tappable
                        Button(action: onToggleLock) {
                            Image(systemName: location.isLocked ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(location.isLocked ? .orange : .gray.opacity(0.3))
                                .font(.system(size: 12))
                                .frame(width: 14)
                        }
                        .buttonStyle(.plain)
                        
                        Text(location.locationName)
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        // Timezone abbreviation - only show when expanded
                        if isExpanded {
                            Text(location.timeZone.abbreviation() ?? location.timeZone.identifier)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .transition(.opacity)
                        }
                        
                        Spacer()
                        
                        Text(formattedTime())
                            .font(.system(size: 16, design: .rounded))
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .opacity(showColon ? 1.0 : 0.3)
                        
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(location.isLocked ? .gray.opacity(0.3) : .red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(location.isLocked)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .frame(width: cardWidth)
                    .background(
                        ZStack {
                            // When expanded, show white background
                            // When collapsed, fade to more transparent material
                            if isExpanded {
                                Color.white
                            } else {
                                if backgroundOpacity > 0 {
                                    Color.white.opacity(backgroundOpacity)
                                }
                                if backgroundOpacity < 1.0 {
                                    Color.white.opacity(0.5)
                                        .background(.ultraThinMaterial)
                                }
                            }
                        }
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            .offset(x: isExpanded ? expandedOffset : collapsedOffset)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let translation = value.translation.width

                        if isExpanded {
                            // When expanded, only allow dragging right (positive) to collapse
                            dragOffset = max(0, min(translation, collapsedOffset))
                        } else {
                            // When collapsed, allow different behaviors for locked vs unlocked
                            if translation > 0 {
                                // Right swipe - only allow for unlocked items (for delete)
                                if !location.isLocked {
                                    dragOffset = translation
                                }
                            } else {
                                // Left swipe - allow for both locked and unlocked (expand)
                                dragOffset = max(-collapsedOffset, translation)
                            }
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let threshold = collapsedOffset * 0.3

                        if isExpanded {
                            // When expanded, right swipe only collapses (never deletes)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if dragOffset > threshold || velocity > 100 {
                                    isExpanded = false
                                }
                                dragOffset = 0
                            }
                        } else {
                            // When collapsed, check for delete (right swipe) - only for unlocked items
                            if dragOffset > 0 && !location.isLocked {
                                let deleteThreshold = cardWidth * 0.3
                                if dragOffset > deleteThreshold || velocity > 200 {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        dragOffset = cardWidth
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        onDelete()
                                    }
                                    return
                                }
                            }

                            // Handle expand for left swipe (both locked and unlocked)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if abs(dragOffset) > threshold || velocity < -100 {
                                    isExpanded = true
                                }
                                dragOffset = 0
                            }
                        }
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
        }
        .frame(height: isLarge ? 60 : 44)
        .padding(.bottom, (isLarge && isExpanded) ? 20 : 0)  // Add space below when expanded
        .onAppear {
            // When card appears, fade from white to transparent over 4 seconds
            withAnimation(.easeOut(duration: 4.0).delay(1.0)) {
                backgroundOpacity = 0.0
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
            showColon.toggle()  // Toggle colon visibility every second
        }
    }

    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = location.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: currentTime)
    }
}

// MARK: - Times List Screen
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

// MARK: - Open Meeting View
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

// MARK: - Draggable Calendar View
struct DraggableCalendarView: View {
    @Binding var selectedDate: Date
    let timeZone: TimeZone
    @State private var dragOffset: CGFloat = 0
    @State private var currentMonth: Date = Date()
    @GestureState private var isDragging = false
    @State private var lastHapticMinute: Int = -1
    @State private var slideDirection: SlideDirection = .none
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }
    private let daysInWeek = 7
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum SlideDirection {
        case none, left, right
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Timezone indicator
                Text("Meeting time zone: \(timeZone.identifier.replacingOccurrences(of: "_", with: " "))")
                    .font(.caption)
                    .foregroundColor(.pink)
                    .padding(.top, 4)
                
                // Header with month/year (no chevrons)
                HStack {
                    Spacer()
                    
                    Text(monthYearString)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // Day of week headers
                HStack(spacing: 0) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
                
                // Calendar grid - dynamic height
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                    ForEach(daysInMonth, id: \.self) { date in
                        if let date = date {
                            let isPastDate = calendar.compare(date, to: Date(), toGranularity: .day) == .orderedAscending
                            
                            Button(action: {
                                if !isPastDate {
                                    selectDate(date)
                                }
                            }) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 18))
                                    .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                                    .foregroundColor(
                                        calendar.isDate(date, inSameDayAs: selectedDate) ? .white :
                                        isPastDate ? .gray.opacity(0.4) : .primary
                                    )
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(isPastDate)
                        } else {
                            Text("")
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection == .left ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: slideDirection == .left ? .leading : .trailing).combined(with: .opacity)
                ))
                .id(monthYearString) // Force re-render when month changes
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        // Only handle primarily horizontal swipes (ignore vertical scrolling)
                        let horizontalDistance = abs(value.translation.width)
                        let verticalDistance = abs(value.translation.height)
                        guard horizontalDistance > verticalDistance * 1.5 else { return }

                        let threshold: CGFloat = 30
                        let velocity = (value.predictedEndTranslation.width - value.translation.width) / 10

                        // Consider both distance and velocity for more responsive swiping
                        let effectiveSwipe = value.translation.width + velocity

                        if effectiveSwipe > threshold {
                            // Swipe right - previous month (only if not in current month)
                            if !isCurrentMonth {
                                previousMonth()
                            } else {
                                // Strong haptic feedback when trying to go back in time
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.error)
                            }
                        } else if effectiveSwipe < -threshold {
                            // Swipe left - next month
                            nextMonth()
                        }
                    }
            )
            
            Divider()
            
            // Time scrubber
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress indicator
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(timeProgress), height: 8)
                    
                    // Draggable handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                        .offset(x: (geometry.size.width * CGFloat(timeProgress)) - 10)
                }
                .frame(height: 20)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateTime(from: value, in: geometry)
                        }
                )
            }
            .frame(height: 20)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .onAppear {
            currentMonth = selectedDate
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: selectedDate)
    }
    
    private var timeProgress: CGFloat {
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)
        let totalMinutes = hour * 60 + minute
        return CGFloat(totalMinutes) / (24 * 60)
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        
        var days: [Date?] = []
        
        // Add empty days for padding at start
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days in month
        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        return days
    }
    
    private func selectDate(_ date: Date) {
        // Trigger haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        // Keep the current time, just change the date
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)
        
        if var components = calendar.dateComponents([.year, .month, .day], from: date) as DateComponents? {
            components.hour = hour
            components.minute = minute
            if let newDate = calendar.date(from: components) {
                selectedDate = newDate
            }
        }
    }
    
    private func updateTime(from value: DragGesture.Value, in geometry: GeometryProxy) {
        // Calculate progress along the slider (0 to 1)
        let sliderWidth = geometry.size.width
        let progress = max(0, min(1, value.location.x / sliderWidth))
        
        // Convert to minutes in day
        let totalMinutes = Int(progress * 24 * 60)
        
        // Snap to 15-minute increments
        let snappedMinutes = (totalMinutes / 15) * 15
        
        // Clamp to valid range (0 to 1439 minutes, which is 23:59)
        let clampedMinutes = min(snappedMinutes, 1439)
        let hour = clampedMinutes / 60
        let minute = clampedMinutes % 60
        
        // Trigger haptic feedback when crossing a 15-minute boundary
        let currentTotalMinutes = hour * 60 + minute
        if currentTotalMinutes != lastHapticMinute {
            hapticFeedback.impactOccurred()
            lastHapticMinute = currentTotalMinutes
        }
        
        // Update the selected date with new time
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = minute
        
        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        }
    }
    
    private func previousMonth() {
        // Don't allow going to months before the current month
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
              calendar.compare(newMonth, to: Date(), toGranularity: .month) != .orderedAscending else {
            return
        }
        
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        slideDirection = .right
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = newMonth
        }
        // Reset direction after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            slideDirection = .none
        }
    }
    
    private func nextMonth() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            slideDirection = .left
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMonth = newMonth
            }
            // Reset direction after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                slideDirection = .none
            }
        }
    }
}

// MARK: - Compact Time Card
struct CompactTimeCard: View {
    let title: String
    let timeZone: TimeZone
    let selectedDate: Date
    let isUserLocation: Bool
    let isSelected: Bool
    let isLocked: Bool
    let locationId: UUID?
    let onDelete: (() -> Void)?
    let onTap: () -> Void
    let onToggleLock: (() -> Void)?
    
    // Random stub image selection
    let stubImages = ["stub-dawn", "stub-night", "stub-midmorning", "stub-midday", "stub-midafternoon", "stub-earlyevening"]
    var randomStub: String {
        // Use title hash for consistent randomness per location
        let hash = abs(title.hashValue)
        return stubImages[hash % stubImages.count]
    }
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @State private var isThresholdReached = false
    @State private var showingDeleteConfirmation = false
    @State private var cardWidth: CGFloat = 350

    var body: some View {
        ZStack(alignment: .trailing) {
            // Red background with trash icon - only shown when actively swiping
            if !isUserLocation && offset < 0 {
                HStack {
                    Spacer()
                    Image(systemName: "trash.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .frame(width: 60)
                        .scaleEffect(isThresholdReached ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: isThresholdReached)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red)
            }

            // Main card content
            HStack(alignment: .center, spacing: 16) {
                // Lock icon - show for all locations
                if isUserLocation {
                    // Your Location - always locked, not tappable
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                        .frame(width: 20)
                } else if let onToggleLock = onToggleLock {
                    // Saved locations - tappable lock toggle
                    Button(action: onToggleLock) {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                            .foregroundColor(isLocked ? .orange : .gray.opacity(0.3))
                            .font(.system(size: 16))
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                }
                
                // Location name and time difference - flexible, can truncate
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if !isUserLocation {
                        Text(timeDifference())
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Time and date - fixed size to prevent wrapping
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedTime())
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                    
                    Text(formattedDate())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color(red: 1.0, green: 0.9, blue: 0.95) :
                isUserLocation ? Color.blue.opacity(0.1) :
                Color(uiColor: .secondarySystemBackground)
            )
            .cornerRadius(12)
            .offset(x: offset)
            .contentShape(Rectangle())
            .onTapGesture {
                // Trigger haptic feedback
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
                onTap()
            }
            .simultaneousGesture(isUserLocation ? nil :
                DragGesture(minimumDistance: 20)
                    .onChanged { gesture in
                        // Don't allow swiping locked items
                        guard !isLocked else { return }
                        
                        let translation = gesture.translation
                        let horizontalMovement = abs(translation.width)
                        let verticalMovement = abs(translation.height)

                        // Only activate if horizontal movement is at least 3x the vertical movement
                        // AND there's at least 30 points of horizontal movement
                        if horizontalMovement > verticalMovement * 3 && horizontalMovement > 30 {
                            // Only allow swiping left (negative offset)
                            if translation.width < 0 {
                                offset = translation.width

                                // Check if pulse threshold is reached (35% for pulsing)
                                let pulseThreshold = -cardWidth * 0.35

                                if offset < pulseThreshold {
                                    if !isThresholdReached {
                                        isThresholdReached = true
                                        // Haptic feedback when pulse threshold is crossed
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                        impactFeedback.impactOccurred()
                                    }
                                } else {
                                    if isThresholdReached {
                                        isThresholdReached = false
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { gesture in
                        // Don't allow swiping locked items
                        guard !isLocked else { return }
                        
                        let translation = gesture.translation
                        let horizontalMovement = abs(translation.width)
                        let verticalMovement = abs(translation.height)

                        // Only process if it was primarily horizontal (3x ratio + 30pt minimum)
                        if horizontalMovement > verticalMovement * 3 && horizontalMovement > 30 {
                            let deleteThreshold = -cardWidth * 0.40

                            if offset < deleteThreshold {
                                // Swipe far enough - show confirmation
                                showingDeleteConfirmation = true
                                // Snap back while showing confirmation
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                    isThresholdReached = false
                                }
                            } else {
                                // Not far enough - snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    offset = 0
                                    isThresholdReached = false
                                }
                            }
                        } else {
                            // Was a vertical swipe or not strong enough horizontal, reset
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                                isThresholdReached = false
                            }
                        }
                    }
            )
        }
        .cornerRadius(12)
        .clipped()
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { cardWidth = geo.size.width }
            }
        )
        .onAppear {
            // Reset swipe state when card appears (fixes stuck red row after loading meetings)
            offset = 0
            isThresholdReached = false
            isSwiping = false
        }
        .alert("Delete Location", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation(.easeOut(duration: 0.3)) {
                    offset = -500 // Slide off screen
                }
                
                // Trigger delete after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDelete?()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(title)?")
        }
    }
    
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: selectedDate)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }
    
    func timeDifference() -> String {
        let userOffset = TimeZone.current.secondsFromGMT(for: selectedDate)
        let targetOffset = timeZone.secondsFromGMT(for: selectedDate)
        let differenceInSeconds = targetOffset - userOffset
        
        if differenceInSeconds == 0 {
            return "same time"
        }
        
        let hours = abs(differenceInSeconds) / 3600
        let minutes = (abs(differenceInSeconds) % 3600) / 60
        
        let sign = differenceInSeconds > 0 ? "+" : ""
        let hourValue = differenceInSeconds > 0 ? hours : -hours
        
        if minutes == 0 {
            return "\(sign)\(hourValue)h"
        } else if minutes == 30 {
            return "\(sign)\(hourValue).5h"
        } else {
            return "\(sign)\(hourValue):\(String(format: "%02d", minutes))h"
        }
    }
}

// MARK: - Time Conversion Card
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

// MARK: - Helper for Dynamic Shape
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

#Preview {
    ContentView()
}

