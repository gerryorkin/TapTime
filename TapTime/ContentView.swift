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

#Preview {
    ContentView()
}
