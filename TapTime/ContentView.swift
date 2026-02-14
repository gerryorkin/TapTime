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

// MARK: - Map Selection Screen
struct MapSelectionView: View {
    @ObservedObject var locationManager: LocationManager
    let onDone: () -> Void
    
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
    @State private var currentTime = Date()
    @State private var showingSearchField = false
    @State private var showingSettings = false
    @State private var showingClearConfirmation = false
    @State private var showingOceanAlert = false
    @State private var showingDuplicateAlert = false
    @FocusState private var isSearchFieldFocused: Bool
    @AppStorage("useLargePills") private var useLargePills = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
            .onReceive(timer) { time in
                currentTime = time
            }

            // Settings and Clear buttons at top left
            VStack {
                HStack {
                    HStack(spacing: 10) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }

                        Button(action: {
                            showingClearConfirmation = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .disabled(locationManager.savedLocations.isEmpty)
                        .opacity(locationManager.savedLocations.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.leading)

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
                                currentTime: currentTime,
                                isLarge: useLargePills,
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        locationManager.removeLocation(location)
                                    }
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
                                    Text("Done")
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
                .padding(.top, 60)
                .padding(.trailing)

                Spacer()
            }

            // Search button floating on the map (bottom left)
            if !showingSearchField {
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            showingSearchField = true
                            isSearchFieldFocused = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
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
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
        .alert("Clear All Locations", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    locationManager.savedLocations.removeAll()
                }
            }
        } message: {
            Text("Are you sure you want to remove all saved locations?")
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

// MARK: - Floating Location Card
struct FloatingLocationCard: View {
    let location: SavedLocation
    let currentTime: Date
    let isLarge: Bool
    let onDelete: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isExpanded = false  // Start collapsed (55% visible)
    @GestureState private var isDragging = false
    @State private var backgroundOpacity: Double = 1.0  // Start white, fade to transparent
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let collapsedOffset = cardWidth * 0.45  // 45% off-screen (55% visible)
            let expandedOffset: CGFloat = 0  // Fully visible
            
            Group {
                if isLarge {
                    // Large pills: Two-line layout with right-aligned time
                    HStack(spacing: 16) {
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
                        
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
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
                        
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
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
                            // When collapsed, allow dragging left (expand) or right (delete)
                            if translation > 0 {
                                dragOffset = translation // Right swipe — no limit, for delete
                            } else {
                                dragOffset = max(-collapsedOffset, translation) // Left swipe — expand
                            }
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let threshold = collapsedOffset * 0.3

                        if !isExpanded && dragOffset > 0 {
                            // Collapsed pill swiped right — check for delete
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

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if isExpanded {
                                if dragOffset > threshold || velocity > 100 {
                                    isExpanded = false
                                }
                            } else {
                                if abs(dragOffset) > threshold || velocity < -100 {
                                    isExpanded = true
                                }
                            }

                            dragOffset = 0
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
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = location.timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: currentTime)
    }
}

// MARK: - Location Row
struct LocationRow: View {
    let location: SavedLocation
    let currentTime: Date
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.locationName)
                    .font(.headline)
                
                Text(location.timeZone.abbreviation() ?? location.timeZone.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formattedTime())
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .monospacedDigit()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .contentShape(Rectangle())
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
    
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Back button
            HStack {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Map")
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("World Times")
                    .font(.headline)
                
                Spacer()
                
                // Placeholder for alignment
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Map")
                }
                .hidden()
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Interactive Calendar and Time Scrubber
            DraggableCalendarView(selectedDate: $selectedDate)
            
            Divider()
            
            // Scrollable list of locations
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    // User's location
                    CompactTimeCard(
                        title: "Your Location",
                        timeZone: locationManager.userTimeZone,
                        selectedDate: selectedDate,
                        isUserLocation: true,
                        onDelete: nil
                    )
                    .padding(.horizontal, 16)
                    
                    // Saved locations
                    ForEach(locationManager.savedLocations) { location in
                        CompactTimeCard(
                            title: location.locationName,
                            timeZone: location.timeZone,
                            selectedDate: selectedDate,
                            isUserLocation: false,
                            onDelete: {
                                // Delete with animation
                                withAnimation {
                                    locationManager.removeLocation(location)
                                }
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            .scrollDisabled(false)
            
            Divider()
            
            // Share button at the bottom
            Button(action: {
                shareSchedule()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Schedule")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .persistentSystemOverlays(.hidden)
    }
    
    func shareSchedule() {
        // Create a formatted text schedule
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var scheduleText = "World Times Schedule\n"
        scheduleText += "Selected: \(formatter.string(from: selectedDate))\n\n"
        
        // Add user location
        formatter.timeZone = locationManager.userTimeZone
        scheduleText += "Your Location:\n"
        scheduleText += "\(formatter.string(from: selectedDate))\n"
        scheduleText += "\(locationManager.userTimeZone.identifier)\n\n"
        
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

// MARK: - Draggable Calendar View
struct DraggableCalendarView: View {
    @Binding var selectedDate: Date
    @State private var dragOffset: CGFloat = 0
    @State private var currentMonth: Date = Date()
    @GestureState private var isDragging = false
    @State private var lastHapticMinute: Int = -1
    @State private var slideDirection: SlideDirection = .none
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum SlideDirection {
        case none, left, right
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
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
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onEnded { value in
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
                        .frame(height: 6)
                    
                    // Progress indicator
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * timeProgress, height: 6)
                    
                    // Draggable handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2.5)
                        )
                        .offset(x: (geometry.size.width * timeProgress) - 12)
                }
                .frame(height: 36)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateTime(from: value, in: geometry)
                        }
                )
            }
            .frame(height: 36)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .onAppear {
            currentMonth = selectedDate
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
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
    let onDelete: (() -> Void)?
    
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
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Red background with trash icon - only for deletable rows
            if !isUserLocation {
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

                // Time only - fixed size to prevent wrapping
                Text(formattedTime())
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isUserLocation ? Color.blue.opacity(0.12) : Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .offset(x: offset)
            .gesture(isUserLocation ? nil :
                DragGesture(minimumDistance: 20)
                    .onChanged { gesture in
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
                                let cardWidth = UIScreen.main.bounds.width - 32
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
                        let translation = gesture.translation
                        let horizontalMovement = abs(translation.width)
                        let verticalMovement = abs(translation.height)

                        // Only process if it was primarily horizontal (3x ratio + 30pt minimum)
                        if horizontalMovement > verticalMovement * 3 && horizontalMovement > 30 {
                            let cardWidth = UIScreen.main.bounds.width - 32
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

// MARK: - Old Time Location Card (for reference, can be removed)
struct TimeLocationCard: View {
    let title: String
    let timeZone: TimeZone
    let currentTime: Date
    let isUserLocation: Bool
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(timeZone.identifier)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formattedTime())
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
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
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: currentTime)
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

