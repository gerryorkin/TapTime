//
//  OrientationManager.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

// Extension to support landscape-only orientation
extension TapTimeApp {
    var supportedOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}
