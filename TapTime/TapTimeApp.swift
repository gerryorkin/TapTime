//
//  TapTimeApp.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

@main
struct TapTimeApp: App {
    init() {
        // Increase the shared URL cache so MapKit map tiles persist across sessions.
        // 64 MB memory / 512 MB disk gives good offline coverage for recently viewed regions.
        let cache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,   // 64 MB
            diskCapacity: 512 * 1024 * 1024,     // 512 MB
            directory: nil                        // default cache directory
        )
        URLCache.shared = cache
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

