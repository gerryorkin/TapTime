//
//  CompactTimeCard.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI
import CoreLocation

struct CompactTimeCard: View {
    let title: String
    let timeZone: TimeZone
    let selectedDate: Date
    let isUserLocation: Bool
    let isSelected: Bool
    let isLocked: Bool
    let locationId: UUID?
    let coordinate: CLLocationCoordinate2D?
    let onDelete: (() -> Void)?
    let onTap: () -> Void
    let onToggleLock: (() -> Void)?
    var rowIndex: Int = 0
    var totalRows: Int = 1
    
    // Reusable date formatters to reduce allocations
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var tzAbbrev: String {
        // Use abbreviation if it's a real name (e.g. AEDT, PST), otherwise GMT offset
        if let abbrev = timeZone.abbreviation(for: selectedDate),
           !abbrev.hasPrefix("GMT"), !abbrev.hasPrefix("+"), !abbrev.hasPrefix("-") {
            return abbrev
        }
        let secs = timeZone.secondsFromGMT(for: selectedDate)
        if secs == 0 { return "GMT" }
        let h = secs / 3600
        let m = abs(secs % 3600) / 60
        if m == 0 {
            return "GMT\(h > 0 ? "+" : "")\(h)"
        } else {
            return "GMT\(secs > 0 ? "+" : "-")\(abs(h)):\(String(format: "%02d", m))"
        }
    }


    @ObservedObject private var photoService = LandmarkPhotoService.shared
    @ObservedObject private var mapService = MapSnapshotService.shared
    @AppStorage("APP_backgroundStyle") private var backgroundStyle: String = "map"
    @AppStorage("APP_fullToneBackground") private var fullToneBackground: Bool = true
    @AppStorage("APP_mapEffect") private var mapEffect: String = "invert"
    @AppStorage("APP_mapStyle") private var mapStyle: String = "muted"
    @AppStorage("APP_mapLocationLabel") private var mapLocationLabel: String = "hidden"
    @AppStorage("APP_tintColorData") private var tintColorData: Data = defaultTintColorData
    @AppStorage("APP_tintPalette") private var tintPalette: Bool = false

    private var tintColor: Color { Color(fromData: tintColorData) }

    /// When palette mode is on, rotate the seed colour's hue evenly across the list.
    private var rowTintColor: Color {
        guard tintPalette, totalRows > 1 else { return tintColor }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tintColor).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let rotation = CGFloat(rowIndex) / CGFloat(totalRows)
        let newHue = (h + rotation).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: Double(newHue), saturation: Double(s), brightness: Double(b), opacity: Double(a))
    }

    private var photoSlug: String {
        LandmarkPhotoService.searchInfo(from: title, timeZone: timeZone).slug
    }

    private var mapShiftSouth: Bool {
        let country: String
        if isUserLocation || title == "Your location" {
            if let code = CountryData.timeZoneToCountryCode[timeZone.identifier] {
                let locale = NSLocale(localeIdentifier: "en_US")
                country = locale.displayName(forKey: .countryCode, value: code) ?? ""
            } else {
                country = ""
            }
        } else {
            let parts = title.split(separator: "/", maxSplits: 1)
            country = (parts.first.map(String.init) ?? title).replacingOccurrences(of: "_", with: " ")
        }
        return country.count > 9
    }

    private var mapSlug: String {
        MapSnapshotService.slug(for: title, timeZone: timeZone, shiftSouth: mapShiftSouth)
    }

    private var countryFlag: String? {
        let countryCode: String?
        if isUserLocation || title == "Your location" {
            countryCode = CountryData.timeZoneToCountryCode[timeZone.identifier]
        } else {
            let parts = title.split(separator: "/", maxSplits: 1)
            let countryName = (parts.first.map(String.init) ?? title).replacingOccurrences(of: "_", with: " ")
            countryCode = CountryData.countryNameToCode[countryName.lowercased()]
        }
        guard let code = countryCode, code.count == 2 else { return nil }
        let base: UInt32 = 0x1F1E6 - 65
        let flag = code.uppercased().unicodeScalars.compactMap { Unicode.Scalar(base + $0.value) }.map { String($0) }.joined()
        return flag.isEmpty ? nil : flag
    }

    private var hasPhoto: Bool {
        switch backgroundStyle {
        case "photos":
            return photoService.photo(forSlug: photoSlug) != nil
        case "map":
            return mapService.snapshot(forSlug: mapSlug) != nil
        case "flag":
            return countryFlag != nil
        default:
            return false
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private var textColor: Color {
        if backgroundStyle == "map" || backgroundStyle == "photos" { return .black }
        return .primary
    }

    /// Whether the current map effect produces a dark background that needs white text.
    private var mapEffectIsDark: Bool {
        ["invert", "grayscale", "tint", "hueRotate"].contains(mapEffect)
    }

    private var locationTextColor: Color {
        if backgroundStyle == "map" && mapEffectIsDark && fullToneBackground { return .white }
        if backgroundStyle == "map" || backgroundStyle == "photos" { return .black }
        return .primary
    }

    private var locationSecondaryTextColor: Color {
        if backgroundStyle == "map" && mapEffectIsDark && fullToneBackground { return .white.opacity(0.8) }
        if backgroundStyle == "map" || backgroundStyle == "photos" { return .black }
        return .secondary
    }

    private var secondaryTextColor: Color {
        if backgroundStyle == "map" || backgroundStyle == "photos" { return .black }
        return .secondary
    }

    private var diffTextColor: Color {
        if backgroundStyle == "map" || backgroundStyle == "photos" { return .black }
        return .blue
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
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // Location name - country on first line, city on second line
                VStack(alignment: .leading, spacing: 1) {
                    let parts = title.split(separator: "/", maxSplits: 1)
                    // First line: always just the country
                    let country = (parts.first.map(String.init) ?? title)
                        .replacingOccurrences(of: "_", with: " ")
                        .replacingOccurrences(of: "United States", with: "USA")
                        .replacingOccurrences(of: "United Kingdom", with: "UK")
                    let showLocationOnMap = backgroundStyle == "map" && mapLocationLabel != "hidden"
                    let mapLabelColor: Color = mapLocationLabel == "white" ? .white : .black
                    if backgroundStyle != "map" || showLocationOnMap {
                        Text(country)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(showLocationOnMap ? mapLabelColor : locationTextColor)
                            .lineLimit(1)
                    }
                    // Second line: city if available (not shown on map rows)
                    if backgroundStyle != "map" {
                        if parts.count > 1 {
                            Text(parts[1].replacingOccurrences(of: "_", with: " "))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(showLocationOnMap ? mapLabelColor.opacity(0.8) : locationSecondaryTextColor)
                                .lineLimit(1)
                        } else if isUserLocation {
                            Text(timeZone.identifier.replacingOccurrences(of: "_", with: " "))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(showLocationOnMap ? mapLabelColor.opacity(0.8) : locationSecondaryTextColor)
                                .lineLimit(1)
                        } else {
                            Text(" ")
                                .font(.subheadline)
                        }
                    }
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 22, height: 22)
                                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            Text("⚓")
                                .font(.system(size: 11))
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, backgroundStyle == "photos" ? 8 : 0)
                .padding(.vertical, backgroundStyle == "photos" ? 4 : 0)
                .background(
                    Group {
                        if backgroundStyle == "photos" {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.55))
                        }
                    }
                )

                Spacer(minLength: 8)

                // Time, date, and timezone info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedTime())
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)

                    Text(formattedDate())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(secondaryTextColor)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(tzAbbrev)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(.horizontal, 16)
                        .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    // Fallback solid color
                    isSelected ? Color.accentColor.opacity(0.15) :
                    isUserLocation ? (colorScheme == .dark ? Color.accentColor.opacity(0.15) : Color.blue.opacity(0.1)) :
                    Color(uiColor: .secondarySystemBackground)

                    // Background overlay based on style
                    switch backgroundStyle {
                    case "photos":
                        LandmarkPhotoView(locationName: title, timeZone: timeZone)
                            .id(photoService.cacheVersion)
                    case "map":
                        if let image = mapService.snapshot(forSlug: mapSlug) {
                            let mapOpacity = fullToneBackground ? 1.0 : (colorScheme == .dark ? 0.5 : (mapEffectIsDark ? 0.35 : 0.5))
                            GeometryReader { geo in
                                let baseImage = Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .saturation(1.5)
                                    .contrast(1.2)
                                    .opacity(mapOpacity)
                                switch mapEffect {
                                case "invert":
                                    baseImage.colorInvert()
                                case "grayscale":
                                    baseImage.grayscale(1.0)
                                case "sepia":
                                    baseImage.grayscale(1.0)
                                        .colorMultiply(Color(red: 0.9, green: 0.8, blue: 0.65))
                                case "hueRotate":
                                    baseImage.hueRotation(.degrees(180))
                                case "tint":
                                    baseImage.grayscale(0.8)
                                        .colorMultiply(rowTintColor)
                                case "blur":
                                    baseImage.blur(radius: 3)
                                default:
                                    baseImage
                                }
                            }
                            .clipped()
                        }
                    case "flag":
                        if !isUserLocation, let flag = countryFlag {
                            Text(flag)
                                .font(.system(size: 73))
                                .frame(maxWidth: .infinity)
                                .offset(x: -1, y: -8)
                        }
                    default:
                        EmptyView()
                    }

                    // White bars behind text areas for readability
                    if backgroundStyle == "map" || backgroundStyle == "photos" {
                        HStack(spacing: 0) {
                            Spacer()
                            Color.white.opacity(0.55)
                                .frame(width: 140)
                        }
                    }
                }
            )
            .overlay(alignment: .topLeading) {
                // Lock icon at top-left corner (hidden for now)
                Group {
                    if isUserLocation {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                    } else if let onToggleLock = onToggleLock {
                        Button(action: onToggleLock) {
                            Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(isLocked ? .orange : .gray.opacity(0.3))
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .hidden()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .cornerRadius(12)
            .clipped()
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
            .offset(x: offset)
            .contentShape(Rectangle())
            .onTapGesture {
                // Trigger haptic feedback
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
                onTap()
            }
            .simultaneousGesture(isUserLocation ? nil :
                DragGesture(minimumDistance: 30)
                    .onChanged { gesture in
                        guard !isLocked else { return }

                        let translation = gesture.translation
                        let horizontalMovement = abs(translation.width)
                        let verticalMovement = abs(translation.height)

                        // Commit to swiping only once, on first significant movement
                        if !isSwiping {
                            guard horizontalMovement > verticalMovement * 2
                                    && translation.width < 0
                                    && horizontalMovement > 30 else { return }
                            isSwiping = true
                        }

                        // Track the horizontal offset
                        if translation.width < 0 {
                            offset = translation.width

                            let pulseThreshold = -cardWidth * 0.35
                            if offset < pulseThreshold {
                                if !isThresholdReached {
                                    isThresholdReached = true
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                }
                            } else if isThresholdReached {
                                isThresholdReached = false
                            }
                        }
                    }
                    .onEnded { _ in
                        defer { isSwiping = false }
                        guard isSwiping else { return }

                        let deleteThreshold = -cardWidth * 0.40

                        if offset < deleteThreshold {
                            showingDeleteConfirmation = true
                        }

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                            isThresholdReached = false
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

            // One-time migration: APP_showLandmarkPhotos (Bool) -> APP_backgroundStyle (String)
            if UserDefaults.standard.object(forKey: "APP_showLandmarkPhotos") != nil {
                let oldValue = UserDefaults.standard.bool(forKey: "APP_showLandmarkPhotos")
                if !oldValue {
                    backgroundStyle = "none"
                }
                UserDefaults.standard.removeObject(forKey: "APP_showLandmarkPhotos")
            }

            // One-time migration: APP_invertMaps (Bool) -> APP_mapEffect (String)
            if UserDefaults.standard.object(forKey: "APP_invertMaps") != nil {
                let wasInverted = UserDefaults.standard.bool(forKey: "APP_invertMaps")
                mapEffect = wasInverted ? "invert" : "none"
                UserDefaults.standard.removeObject(forKey: "APP_invertMaps")
            }

            // One-time migration: APP_mapMuted (Bool) -> APP_mapStyle (String)
            if UserDefaults.standard.object(forKey: "APP_mapMuted") != nil {
                let wasMuted = UserDefaults.standard.bool(forKey: "APP_mapMuted")
                mapStyle = wasMuted ? "muted" : "standard"
                UserDefaults.standard.removeObject(forKey: "APP_mapMuted")
            }

            // Trigger background load based on style
            switch backgroundStyle {
            case "photos":
                let info = LandmarkPhotoService.searchInfo(from: title, timeZone: timeZone)
                if !info.query.isEmpty {
                    photoService.loadPhoto(query: info.query, slug: info.slug)
                }
            case "map":
                if let coord = coordinate {
                    let slug = MapSnapshotService.slug(for: title, timeZone: timeZone, shiftSouth: mapShiftSouth)
                    mapService.loadSnapshot(locationName: title, timeZone: timeZone, fallbackCoordinate: coord, slug: slug, shiftSouth: mapShiftSouth)
                }
            default:
                break
            }
        }
        .onChange(of: backgroundStyle) { _, newStyle in
            switch newStyle {
            case "photos":
                let info = LandmarkPhotoService.searchInfo(from: title, timeZone: timeZone)
                if !info.query.isEmpty {
                    photoService.loadPhoto(query: info.query, slug: info.slug)
                }
            case "map":
                if let coord = coordinate {
                    let slug = MapSnapshotService.slug(for: title, timeZone: timeZone, shiftSouth: mapShiftSouth)
                    mapService.loadSnapshot(locationName: title, timeZone: timeZone, fallbackCoordinate: coord, slug: slug, shiftSouth: mapShiftSouth)
                }
            default:
                break
            }
        }
        .onChange(of: mapStyle) { _, _ in
            if backgroundStyle == "map", let coord = coordinate {
                let slug = MapSnapshotService.slug(for: title, timeZone: timeZone, shiftSouth: mapShiftSouth)
                mapService.loadSnapshot(locationName: title, timeZone: timeZone, fallbackCoordinate: coord, slug: slug, shiftSouth: mapShiftSouth)
            }
        }
        .onChange(of: photoService.cacheVersion) { _, _ in
            if backgroundStyle == "photos" {
                let info = LandmarkPhotoService.searchInfo(from: title, timeZone: timeZone)
                if !info.query.isEmpty {
                    photoService.loadPhoto(query: info.query, slug: info.slug)
                }
            }
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
        Self.timeFormatter.timeZone = timeZone
        return Self.timeFormatter.string(from: selectedDate)
    }

    func formattedDate() -> String {
        Self.dateFormatter.timeZone = timeZone
        return Self.dateFormatter.string(from: selectedDate)
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
