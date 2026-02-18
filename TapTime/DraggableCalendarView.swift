//
//  DraggableCalendarView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct DraggableCalendarView: View {
    @Binding var selectedDate: Date
    let timeZone: TimeZone
    @State private var dragOffset: CGFloat = 0
    @State private var currentMonth: Date = Date()
    @GestureState private var isDragging = false
    @State private var lastHapticMinute: Int = -1
    @State private var slideDirection: SlideDirection = .none

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }
    private let daysInWeek = 7
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)

    enum SlideDirection {
        case none, left, right
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Timezone indicator
                Text("Meeting time zone: \(timeZone.identifier.replacingOccurrences(of: "_", with: " "))")
                    .font(.caption)
                    .foregroundColor(.pink)
                    .padding(.top, 4)

                // Header with month/year (no chevrons)
                HStack {
                    Spacer()

                    Text(monthYearString)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Day of week headers
                HStack(spacing: 0) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 4)

                // Calendar grid - dynamic height
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                    ForEach(daysInMonth, id: \.self) { date in
                        if let date = date {
                            let isPastDate = calendar.compare(date, to: Date(), toGranularity: .day) == .orderedAscending

                            Button(action: {
                                if !isPastDate {
                                    selectDate(date)
                                }
                            }) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.system(size: 18))
                                    .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .regular)
                                    .foregroundColor(
                                        calendar.isDate(date, inSameDayAs: selectedDate) ? .white :
                                        isPastDate ? .gray.opacity(0.4) : .primary
                                    )
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(isPastDate)
                        } else {
                            Text("")
                                .frame(width: 32, height: 32)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: slideDirection == .left ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: slideDirection == .left ? .leading : .trailing).combined(with: .opacity)
                ))
                .id(monthYearString) // Force re-render when month changes
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        // Only handle primarily horizontal swipes (ignore vertical scrolling)
                        let horizontalDistance = abs(value.translation.width)
                        let verticalDistance = abs(value.translation.height)
                        guard horizontalDistance > verticalDistance * 1.5 else { return }

                        let threshold: CGFloat = 30
                        let velocity = (value.predictedEndTranslation.width - value.translation.width) / 10

                        // Consider both distance and velocity for more responsive swiping
                        let effectiveSwipe = value.translation.width + velocity

                        if effectiveSwipe > threshold {
                            // Swipe right - previous month (only if not in current month)
                            if !isCurrentMonth {
                                previousMonth()
                            } else {
                                // Strong haptic feedback when trying to go back in time
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.notificationOccurred(.error)
                            }
                        } else if effectiveSwipe < -threshold {
                            // Swipe left - next month
                            nextMonth()
                        }
                    }
            )

            Divider()

            // Time scrubber
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Progress indicator
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(timeProgress), height: 8)

                    // Draggable handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                        .offset(x: (geometry.size.width * CGFloat(timeProgress)) - 10)
                }
                .frame(height: 20)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateTime(from: value, in: geometry)
                        }
                )
            }
            .frame(height: 20)
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .onAppear {
            currentMonth = selectedDate
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: selectedDate)
    }

    private var timeProgress: CGFloat {
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)
        let totalMinutes = hour * 60 + minute
        return CGFloat(totalMinutes) / (24 * 60)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }

        var days: [Date?] = []

        // Add empty days for padding at start
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        // Add all days in month
        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return days
    }

    private func selectDate(_ date: Date) {
        // Trigger haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        // Keep the current time, just change the date
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)

        if var components = calendar.dateComponents([.year, .month, .day], from: date) as DateComponents? {
            components.hour = hour
            components.minute = minute
            if let newDate = calendar.date(from: components) {
                selectedDate = newDate
            }
        }
    }

    private func updateTime(from value: DragGesture.Value, in geometry: GeometryProxy) {
        // Calculate progress along the slider (0 to 1)
        let sliderWidth = geometry.size.width
        let progress = max(0, min(1, value.location.x / sliderWidth))

        // Convert to minutes in day
        let totalMinutes = Int(progress * 24 * 60)

        // Snap to 15-minute increments
        let snappedMinutes = (totalMinutes / 15) * 15

        // Clamp to valid range (0 to 1439 minutes, which is 23:59)
        let clampedMinutes = min(snappedMinutes, 1439)
        let hour = clampedMinutes / 60
        let minute = clampedMinutes % 60

        // Trigger haptic feedback when crossing a 15-minute boundary
        let currentTotalMinutes = hour * 60 + minute
        if currentTotalMinutes != lastHapticMinute {
            hapticFeedback.impactOccurred()
            lastHapticMinute = currentTotalMinutes
        }

        // Update the selected date with new time
        var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        components.hour = hour
        components.minute = minute

        if let newDate = calendar.date(from: components) {
            selectedDate = newDate
        }
    }

    private func previousMonth() {
        // Don't allow going to months before the current month
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
              calendar.compare(newMonth, to: Date(), toGranularity: .month) != .orderedAscending else {
            return
        }

        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        slideDirection = .right
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = newMonth
        }
        // Reset direction after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            slideDirection = .none
        }
    }

    private func nextMonth() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            slideDirection = .left
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMonth = newMonth
            }
            // Reset direction after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                slideDirection = .none
            }
        }
    }
}
