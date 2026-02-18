//
//  PillStyle.swift
//  TapTime
//
//  Created by Gerry Orkin on 19/2/2026.
//

import SwiftUI

// MARK: - Color ↔ Data helpers for @AppStorage

extension Color {
    /// Encode a Color as Data for @AppStorage persistence.
    func toData() -> Data {
        let uiColor = UIColor(self)
        return (try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false)) ?? Data()
    }

    /// Decode a Color from Data stored in @AppStorage.
    init(fromData data: Data) {
        if let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
            self = Color(uiColor)
        } else {
            self = .white
        }
    }
}

/// Default pill colour data (white) for @AppStorage default value.
let defaultPillColorData: Data = Color.white.toData()

// MARK: - PillStyle

struct PillStyle {
    let backgroundColor: Color
    let opacity: Double

    /// Primary text/icon colour — auto-contrasts against the background.
    var foregroundColor: Color {
        luminance > 0.55 ? .black : .white
    }

    /// Secondary text colour (timezone abbreviations, etc.)
    var secondaryForegroundColor: Color {
        luminance > 0.55
            ? Color.black.opacity(0.5)
            : Color.white.opacity(0.6)
    }

    /// Lock icon colour when locked.
    var lockActiveColor: Color { .orange }

    /// Lock icon colour when unlocked.
    var lockInactiveColor: Color {
        luminance > 0.55
            ? Color.gray.opacity(0.3)
            : Color.white.opacity(0.25)
    }

    /// Delete button colour.
    var deleteColor: Color { .red }

    /// Delete button colour when disabled (locked).
    var deleteDisabledColor: Color { lockInactiveColor }

    /// Shadow colour.
    var shadowColor: Color {
        luminance > 0.55
            ? Color.black.opacity(0.2)
            : Color.black.opacity(0.35)
    }

    // MARK: - Private

    /// Relative luminance of the background colour.
    private var luminance: Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(backgroundColor).getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }
}
