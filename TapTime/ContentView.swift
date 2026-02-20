//
//  ContentView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @AppStorage("showingTimesList") private var showingTimesList = false

    var body: some View {
        Group {
            if showingTimesList {
                TimesListView(
                    locationManager: locationManager,
                    onBack: {
                        showingTimesList = false
                    }
                )
                .transition(.identity)
            } else {
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
                .transition(.identity)
            }
        }
        .animation(nil, value: showingTimesList)
        .onAppear {
            MapTileCache.prewarm(locations: locationManager.savedLocations.map(\.coordinate))
        }
        .onChange(of: locationManager.savedLocations) { _, newLocations in
            MapTileCache.prewarm(locations: newLocations.map(\.coordinate))
        }
    }
}

#Preview {
    ContentView()
}
