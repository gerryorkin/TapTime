//
//  MapSelectionView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI
import MapKit
internal import Combine

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
    @AppStorage("hasShownFirstLaunchHelp") private var hasShownFirstLaunchHelp = false
    @State private var isMapScrolling = false
    @State private var saveMapTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            // Full screen map
            DraggableMapView(
                locationManager: locationManager,
                cameraPosition: $mapRegion,
                isMapScrolling: $isMapScrolling,
                onTap: { coordinate in
                    Task {
                        let result = await locationManager.addLocation(at: coordinate)
                        switch result {
                        case .duplicate:
                            showingDuplicateAlert = true
                        case .multipleTimeZones(_, let countryCode, _):
                            // Reuse the existing search-results picker
                            let locale = NSLocale(localeIdentifier: "en_US")
                            let countryName = locale.displayName(forKey: .countryCode, value: countryCode) ?? countryCode
                            let results = locationManager.searchLocations(query: countryName)
                            if !results.isEmpty {
                                searchResults = results
                                showingSearchField = true
                                withAnimation {
                                    showingSearchResults = true
                                }
                            }
                        default:
                            break
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
                scheduleSaveMapPosition()
            }
            .onChange(of: mapRegion.center.longitude) { _, _ in
                scheduleSaveMapPosition()
            }
            .onChange(of: mapRegion.span.latitudeDelta) { _, _ in
                scheduleSaveMapPosition()
            }
            .onChange(of: mapRegion.span.longitudeDelta) { _, _ in
                scheduleSaveMapPosition()
            }
            .ignoresSafeArea()

            // Buttons at bottom left — pill style matching location cards
            if !showingSearchField {
            VStack {
                Spacer()
                HStack {
                    VStack(spacing: -4) {
                        LeftPillButton(
                            icon: "xmark.circle.fill",
                            label: "Clear",
                            isLarge: useLargePills,
                            action: { showingClearConfirmation = true }
                        )
                        .disabled(locationManager.savedLocations.filter { !$0.isLocked }.isEmpty)
                        .opacity(locationManager.savedLocations.filter { !$0.isLocked }.isEmpty ? 0.5 : 1.0)

                        LeftPillButton(
                            icon: "magnifyingglass",
                            label: "Search",
                            isLarge: useLargePills,
                            action: {
                                showingSearchField = true
                                isSearchFieldFocused = true
                            }
                        )
                        .padding(.top, 12)

                        LeftPillButton(
                            icon: "gearshape.fill",
                            label: "Settings",
                            isLarge: useLargePills,
                            action: { showingSettings = true }
                        )
                        .padding(.top, 12)

                        LeftPillButton(
                            icon: "questionmark.circle.fill",
                            label: "Help",
                            isLarge: useLargePills,
                            action: { showingHelp = true }
                        )
                        .padding(.top, 12)
                    }
                    .frame(width: 200)

                    Spacer()
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(.keyboard)
            .opacity(isMapScrolling ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: isMapScrolling)
            }

            // Location pills at the top right
            VStack {
                HStack {
                    Spacer()

                    VStack(spacing: 8) {
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
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
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
            .opacity(isMapScrolling ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: isMapScrolling)

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
        .onAppear {
            if !hasShownFirstLaunchHelp {
                hasShownFirstLaunchHelp = true
                showingHelp = true
            }
        }
    }

    private func scheduleSaveMapPosition() {
        saveMapTask?.cancel()
        saveMapTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveMapPosition()
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
                if case .duplicate = addResult {
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
