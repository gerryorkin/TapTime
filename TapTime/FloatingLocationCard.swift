//
//  FloatingLocationCard.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI
internal import Combine

struct FloatingLocationCard: View {
    let location: SavedLocation
    let isLarge: Bool
    let onDelete: () -> Void
    let onToggleLock: () -> Void

    @State private var currentTime = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var isExpanded = false  // Start collapsed (55% visible)
    @GestureState private var isDragging = false
    @State private var backgroundOpacity: Double = 1.0  // Start white, fade to transparent
    @State private var showColon = true  // For flashing colon

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let collapsedOffset = cardWidth * 0.45  // 45% off-screen (55% visible)
            let expandedOffset: CGFloat = 0  // Fully visible

            Group {
                if isLarge {
                    // Large pills: Two-line layout with right-aligned time
                    HStack(spacing: 16) {
                        // Lock icon on the left - tappable
                        Button(action: onToggleLock) {
                            Image(systemName: location.isLocked ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(location.isLocked ? .orange : .gray.opacity(0.3))
                                .font(.system(size: 14))
                                .frame(width: 16)
                        }
                        .buttonStyle(.plain)

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
                            .opacity(showColon ? 1.0 : 0.3)

                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(location.isLocked ? .gray.opacity(0.3) : .red)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                        .disabled(location.isLocked)
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
                        // Lock icon on the left - tappable
                        Button(action: onToggleLock) {
                            Image(systemName: location.isLocked ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(location.isLocked ? .orange : .gray.opacity(0.3))
                                .font(.system(size: 12))
                                .frame(width: 14)
                        }
                        .buttonStyle(.plain)

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
                            .opacity(showColon ? 1.0 : 0.3)

                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(location.isLocked ? .gray.opacity(0.3) : .red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(location.isLocked)
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
                            // When collapsed, allow different behaviors for locked vs unlocked
                            if translation > 0 {
                                // Right swipe - only allow for unlocked items (for delete)
                                if !location.isLocked {
                                    dragOffset = translation
                                }
                            } else {
                                // Left swipe - allow for both locked and unlocked (expand)
                                dragOffset = max(-collapsedOffset, translation)
                            }
                        }
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let threshold = collapsedOffset * 0.3

                        if isExpanded {
                            // When expanded, right swipe only collapses (never deletes)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if dragOffset > threshold || velocity > 100 {
                                    isExpanded = false
                                }
                                dragOffset = 0
                            }
                        } else {
                            // When collapsed, check for delete (right swipe) - only for unlocked items
                            if dragOffset > 0 && !location.isLocked {
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

                            // Handle expand for left swipe (both locked and unlocked)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if abs(dragOffset) > threshold || velocity < -100 {
                                    isExpanded = true
                                }
                                dragOffset = 0
                            }
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
        .onReceive(timer) { _ in
            currentTime = Date()
            showColon.toggle()  // Toggle colon visibility every second
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
