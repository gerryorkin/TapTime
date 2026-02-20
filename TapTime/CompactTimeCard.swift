//
//  CompactTimeCard.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

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

                // Location name - country on first line, city on second line
                VStack(alignment: .leading, spacing: 1) {
                    let parts = title.split(separator: "/", maxSplits: 1)
                    // First line: always just the country
                    Text((parts.first.map(String.init) ?? title).replacingOccurrences(of: "_", with: " "))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    // Second line: always show city if available
                    if parts.count > 1 {
                        Text(parts[1].replacingOccurrences(of: "_", with: " "))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if isSelected {
                    Text("⚓")
                        .font(.system(size: 20))
                }

                Spacer(minLength: 8)

                // Time, date, and hours difference - fixed size to prevent wrapping
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

                    if !isUserLocation {
                        Text(timeDifference())
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fixedSize(horizontal: true, vertical: false)
                    }
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
