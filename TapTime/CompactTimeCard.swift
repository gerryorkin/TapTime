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

    @ObservedObject private var photoService = LandmarkPhotoService.shared
    @ObservedObject private var mapService = MapSnapshotService.shared
    @AppStorage("APP_backgroundStyle") private var backgroundStyle: String = "photos"
    @AppStorage("APP_fullToneBackground") private var fullToneBackground: Bool = false

    private var photoSlug: String {
        LandmarkPhotoService.searchInfo(from: title, timeZone: timeZone).slug
    }

    private var mapSlug: String {
        MapSnapshotService.slug(for: title, timeZone: timeZone)
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
            HStack(alignment: .center, spacing: 12) {
                // Location name - country on first line, city on second line
                VStack(alignment: .leading, spacing: 1) {
                    let parts = title.split(separator: "/", maxSplits: 1)
                    // First line: always just the country
                    Text((parts.first.map(String.init) ?? title).replacingOccurrences(of: "_", with: " "))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    // Second line: city if available, invisible spacer for consistent height
                    if parts.count > 1 {
                        Text(parts[1].replacingOccurrences(of: "_", with: " "))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if isUserLocation {
                        Text(timeZone.identifier.replacingOccurrences(of: "_", with: " "))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(" ")
                            .font(.subheadline)
                    }
                }

                Spacer(minLength: 8)

                // Time, date, and hours difference - fixed size to prevent wrapping
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedTime())
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)

                    Text(formattedDate())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: true, vertical: false)

                    if !isUserLocation {
                        Text(timeDifference())
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fixedSize(horizontal: true, vertical: false)
                    } else {
                        Text(" ")
                            .font(.caption)
                    }
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
                    case "map":
                        if let image = mapService.snapshot(forSlug: mapSlug) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(fullToneBackground ? 1.0 : 0.3)
                        }
                    case "flag":
                        if !isUserLocation, let flag = countryFlag {
                            Text(flag)
                                .font(.system(size: 96))
                                .opacity(fullToneBackground ? 1.0 : 0.15)
                                .frame(maxWidth: .infinity)
                        }
                    default:
                        EmptyView()
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
            .overlay(alignment: .topLeading) {
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        Text("⚓")
                            .font(.system(size: 9))
                    }
                    .padding(6)
                }
            }
            .cornerRadius(12)
            .clipped()
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

            // Trigger background load based on style
            switch backgroundStyle {
            case "photos":
                let info = LandmarkPhotoService.searchInfo(from: title, timeZone: timeZone)
                if !info.query.isEmpty {
                    photoService.loadPhoto(query: info.query, slug: info.slug)
                }
            case "map":
                if let coord = coordinate {
                    let slug = MapSnapshotService.slug(for: title, timeZone: timeZone)
                    mapService.loadSnapshot(locationName: title, timeZone: timeZone, fallbackCoordinate: coord, slug: slug)
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
                    let slug = MapSnapshotService.slug(for: title, timeZone: timeZone)
                    mapService.loadSnapshot(locationName: title, timeZone: timeZone, fallbackCoordinate: coord, slug: slug)
                }
            default:
                break
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
