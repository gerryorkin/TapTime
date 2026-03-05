//
//  TimelineComparisonView.swift
//  TapTime
//

import SwiftUI

// MARK: - Data Types

/// Time-of-day period for cell colouring — uses a warm/cool spectrum
/// (indigo night → peach dawn → warm white day → amber dusk).
private enum DayPeriod {
    case night, predawn, dawn, morning, midday, afternoon, dusk, evening

    var color: Color {
        switch self {
        case .night:     return Color(red: 0.10, green: 0.12, blue: 0.28)
        case .predawn:   return Color(red: 0.18, green: 0.22, blue: 0.42)
        case .dawn:      return Color(red: 0.32, green: 0.46, blue: 0.66)
        case .morning:   return Color(red: 0.55, green: 0.72, blue: 0.88)
        case .midday:    return Color(red: 0.75, green: 0.86, blue: 0.95)
        case .afternoon: return Color(red: 0.60, green: 0.76, blue: 0.90)
        case .dusk:      return Color(red: 0.30, green: 0.40, blue: 0.60)
        case .evening:   return Color(red: 0.15, green: 0.18, blue: 0.35)
        }
    }

    var textColor: Color {
        switch self {
        case .night, .predawn, .evening:
            return .white.opacity(0.85)
        case .dawn, .dusk:
            return .white.opacity(0.9)
        default:
            return Color(red: 0.08, green: 0.10, blue: 0.25)
        }
    }

    static func from(hour: Int) -> DayPeriod {
        switch hour {
        case 0...3:   return .night
        case 4...5:   return .predawn
        case 6:       return .dawn
        case 7...10:  return .morning
        case 11...13: return .midday
        case 14...17: return .afternoon
        case 18...19: return .dusk
        case 20...21: return .evening
        default:      return .night
        }
    }
}

private struct TimelineSlot: Identifiable {
    let id: Int
    let hour: Int
    let hourNum: String
    let ampm: String
    let isNewDay: Bool
    let dayLabel: String   // "Mar 6"
    let period: DayPeriod
}

private struct TimelineRowData: Identifiable {
    let id: UUID
    let locationName: String
    let timeZone: TimeZone
    let tzAbbrev: String
    let offsetLabel: String
    let currentTimeLabel: String
    let slots: [TimelineSlot]
    let isUserLocation: Bool
}

// MARK: - Layout

private enum Layout {
    static let cellWidth: CGFloat = 48
    static let cellGap: CGFloat = 0
    static let stripHeight: CGFloat = 40
    static let labelHeight: CGFloat = 30
    static var blockHeight: CGFloat { labelHeight + stripHeight }
    static let totalSlots = 32
    static let hoursBeforeNow = 14
}

// MARK: - Scroll Offset Tracking

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Main View

struct TimelineComparisonView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("selectedDateTimestamp") private var selectedDateTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("selectedLocationID") private var selectedLocationIDString: String = ""

    /// Stable anchor for content layout — only updated on appear, tap, or scrubber change.
    @State private var stableBaseDate: Date = Date()
    /// Set true during programmatic scrollTo to suppress scroll-driven updates.
    @State private var programmaticScrollActive = false
    /// Width of the scroll viewport (for computing center offset).
    @State private var viewWidth: CGFloat = 0
    /// Whether stableBaseDate has been initialised.
    @State private var initialized = false

    private var selectedDate: Date {
        get { Date(timeIntervalSince1970: selectedDateTimestamp) }
        nonmutating set { selectedDateTimestamp = newValue.timeIntervalSince1970 }
    }

    private var selectedLocationID: UUID? {
        selectedLocationIDString.isEmpty ? nil : UUID(uuidString: selectedLocationIDString)
    }

    private var selectedTimeZone: TimeZone {
        if let selectedID = selectedLocationID,
           let location = locationManager.savedLocations.first(where: { $0.id == selectedID }) {
            return location.timeZone
        }
        return locationManager.userTimeZone
    }

    // MARK: Formatters

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    // MARK: Computed Data

    /// Content layout anchor — returns stable base date.
    private var baseDate: Date { stableBaseDate }

    /// Compute a fresh base date from the current selectedDate.
    private func computeStableBaseDate() -> Date {
        let raw = selectedDate.addingTimeInterval(-Double(Layout.hoursBeforeNow) * 3600)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: raw)
        return cal.date(from: comps) ?? raw
    }

    private var nowOffset: CGFloat {
        let seconds = selectedDate.timeIntervalSince(stableBaseDate)
        let cellSpan = Layout.cellWidth + Layout.cellGap
        return CGFloat(seconds / 3600.0) * cellSpan
    }

    private var rows: [TimelineRowData] {
        var result: [TimelineRowData] = []

        if selectedLocationID == nil {
            result.append(buildRow(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                locationName: "Current time",
                timeZone: locationManager.userTimeZone,
                isUserLocation: true
            ))
        }

        let sorted: [SavedLocation]
        if let selectedID = selectedLocationID {
            var locs = locationManager.savedLocations
            if let idx = locs.firstIndex(where: { $0.id == selectedID }) {
                let sel = locs.remove(at: idx)
                locs.sort { $0.timeZone.secondsFromGMT(for: selectedDate) < $1.timeZone.secondsFromGMT(for: selectedDate) }
                locs.insert(sel, at: 0)
            }
            sorted = locs
        } else {
            sorted = locationManager.savedLocations.sorted {
                $0.timeZone.secondsFromGMT(for: selectedDate) < $1.timeZone.secondsFromGMT(for: selectedDate)
            }
        }

        for loc in sorted {
            result.append(buildRow(
                id: loc.id,
                locationName: loc.locationName,
                timeZone: loc.timeZone,
                isUserLocation: false
            ))
        }

        if selectedLocationID != nil {
            result.append(buildRow(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                locationName: "Current time",
                timeZone: locationManager.userTimeZone,
                isUserLocation: true
            ))
        }

        return result
    }

    private func buildRow(id: UUID, locationName: String, timeZone: TimeZone, isUserLocation: Bool) -> TimelineRowData {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        var slots: [TimelineSlot] = []
        for i in 0..<Layout.totalSlots {
            let slotDate = baseDate.addingTimeInterval(Double(i) * 3600)
            let hour = cal.component(.hour, from: slotDate)

            let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            let ampm = hour < 12 ? "am" : "pm"

            let isNewDay = hour == 0
            Self.monthDayFormatter.timeZone = timeZone
            let dayLabel = isNewDay ? Self.monthDayFormatter.string(from: slotDate) : ""

            slots.append(TimelineSlot(
                id: i,
                hour: hour,
                hourNum: "\(hour12)",
                ampm: ampm,
                isNewDay: isNewDay,
                dayLabel: dayLabel,
                period: DayPeriod.from(hour: hour)
            ))
        }

        let tzAbbrev = timeZone.abbreviation(for: selectedDate) ?? ""

        let userSeconds = locationManager.userTimeZone.secondsFromGMT(for: selectedDate)
        let gmtSeconds = timeZone.secondsFromGMT(for: selectedDate)
        let diffSeconds = gmtSeconds - userSeconds
        let diffHours = diffSeconds / 3600
        let diffMins = abs(diffSeconds % 3600) / 60
        let offsetLabel: String
        if diffSeconds == 0 {
            offsetLabel = ""
        } else if diffMins == 0 {
            offsetLabel = "\(diffHours > 0 ? "+" : "")\(diffHours)h"
        } else if diffMins == 30 {
            let sign = diffSeconds > 0 ? "+" : "-"
            offsetLabel = "\(sign)\(abs(diffHours)).5h"
        } else {
            let sign = diffSeconds > 0 ? "+" : "-"
            offsetLabel = "\(sign)\(abs(diffHours)):\(String(format: "%02d", diffMins))h"
        }

        Self.timeFormatter.timeZone = timeZone
        let currentTimeLabel = Self.timeFormatter.string(from: selectedDate)

        return TimelineRowData(
            id: id,
            locationName: locationName,
            timeZone: timeZone,
            tzAbbrev: tzAbbrev,
            offsetLabel: offsetLabel,
            currentTimeLabel: currentTimeLabel,
            slots: slots,
            isUserLocation: isUserLocation
        )
    }

    @State private var showingCalendar = false

    // MARK: Body

    var body: some View {
        let allRows = rows

        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Timeline")
                    .font(.headline)

                Spacer()

                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()

            // Calendar (hidden by default, toggled by button)
            if showingCalendar {
                DraggableCalendarView(
                    selectedDate: Binding(
                        get: { self.selectedDate },
                        set: { newDate in
                            self.selectedDate = newDate
                            self.stableBaseDate = computeStableBaseDate()
                        }
                    ),
                    timeZone: selectedTimeZone
                )
                .transition(.move(edge: .top).combined(with: .opacity))

                Divider()
            }

            // Main content
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Layer 1: Horizontal-scrollable strips
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            ZStack(alignment: .topLeading) {
                                VStack(spacing: 0) {
                                    ForEach(allRows) { row in
                                        Color.clear.frame(height: Layout.labelHeight)
                                        TimelineRowStrip(row: row) { slotIndex in
                                            let newDate = stableBaseDate.addingTimeInterval(Double(slotIndex) * 3600)
                                            programmaticScrollActive = true
                                            selectedDate = newDate
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                proxy.scrollTo("now-anchor", anchor: .center)
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                                programmaticScrollActive = false
                                            }
                                        }
                                        .frame(height: Layout.stripHeight)
                                    }
                                }

                                // Now marker
                                NowMarker(
                                    offset: nowOffset,
                                    labelHeight: Layout.labelHeight,
                                    stripHeight: Layout.stripHeight,
                                    rowCount: allRows.count
                                )

                                // Scroll anchor
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .id("now-anchor")
                                    .offset(x: nowOffset)
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ScrollOffsetKey.self,
                                        value: geo.frame(in: .named("hscroll")).minX
                                    )
                                }
                            )
                            .onAppear {
                                stableBaseDate = computeStableBaseDate()
                                initialized = true
                                proxy.scrollTo("now-anchor", anchor: .center)
                            }
                            .onChange(of: selectedDateTimestamp) { _, _ in
                                guard !programmaticScrollActive else { return }
                                // Scrubber-driven change: recompute anchor and re-centre
                                stableBaseDate = computeStableBaseDate()
                                programmaticScrollActive = true
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo("now-anchor", anchor: .center)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    programmaticScrollActive = false
                                }
                            }
                        }
                    }
                    .coordinateSpace(name: "hscroll")
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear { viewWidth = geo.size.width }
                                .onChange(of: geo.size.width) { _, w in viewWidth = w }
                        }
                    )
                    .onPreferenceChange(ScrollOffsetKey.self) { contentMinX in
                        guard initialized, !programmaticScrollActive else { return }
                        let centerX = -contentMinX + viewWidth / 2
                        let cellSpan = Layout.cellWidth + Layout.cellGap
                        let hoursFromBase = Double(centerX / cellSpan)
                        let newDate = stableBaseDate.addingTimeInterval(hoursFromBase * 3600)
                        programmaticScrollActive = true
                        selectedDate = newDate
                        // Allow next preference change through quickly
                        DispatchQueue.main.async {
                            programmaticScrollActive = false
                        }
                    }

                    // Layer 2: Pinned labels
                    VStack(spacing: 0) {
                        ForEach(allRows) { row in
                            TimelineRowLabel(row: row)
                                .frame(height: Layout.labelHeight)
                                .background(Color(uiColor: .systemBackground))
                            Color.clear.frame(height: Layout.stripHeight)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }

            Divider()

            // Bottom bar: calendar toggle + time scrubber
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingCalendar.toggle()
                    }
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                TimeScrubberView(
                    selectedDate: Binding(
                        get: { self.selectedDate },
                        set: { self.selectedDate = $0 }
                    ),
                    timeZone: selectedTimeZone
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))
        }
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Row Label (pinned above each strip)

private struct TimelineRowLabel: View {
    let row: TimelineRowData

    private var displayName: String {
        if row.locationName == "Current time" { return "Current time" }
        let parts = row.locationName.split(separator: "/", maxSplits: 1)
        let city: String
        if parts.count > 1 {
            city = String(parts[1]).replacingOccurrences(of: "_", with: " ")
        } else {
            city = (parts.first.map(String.init) ?? row.locationName)
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "United States", with: "USA")
                .replacingOccurrences(of: "United Kingdom", with: "UK")
        }
        return city
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            // Home icon or offset
            if row.isUserLocation && row.offsetLabel.isEmpty {
                Image(systemName: "location.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, alignment: .center)
            } else {
                Text(row.offsetLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 38, alignment: .trailing)
                    .padding(.trailing, 4)
            }

            // Name
            Text(displayName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)

            // TZ abbreviation
            Text(" \(row.tzAbbrev)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)

            Spacer(minLength: 4)

            // Current time
            Text(row.currentTimeLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .padding(.trailing, 14)
        }
        .padding(.leading, 10)
        .padding(.top, 5)
    }
}

// MARK: - Row Strip (gapped rounded cells)

private struct TimelineRowStrip: View {
    let row: TimelineRowData
    let onSlotTap: (Int) -> Void

    var body: some View {
        HStack(spacing: Layout.cellGap) {
            ForEach(row.slots) { slot in
                TimelineHourCell(slot: slot)
                    .onTapGesture {
                        let feedback = UISelectionFeedbackGenerator()
                        feedback.selectionChanged()
                        onSlotTap(slot.id)
                    }
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Hour Cell

private struct TimelineHourCell: View {
    let slot: TimelineSlot

    var body: some View {
        Group {
            if slot.isNewDay {
                // Date boundary — distinct rounded badge
                VStack(spacing: 0) {
                    Text(slot.dayLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: Layout.cellWidth, height: Layout.stripHeight)
                .background(Color(red: 0.0, green: 0.55, blue: 0.60))
                .clipped()
            } else {
                VStack(spacing: 0) {
                    Text(slot.hourNum)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(slot.period.textColor)
                    Text(slot.ampm)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(slot.period.textColor.opacity(0.6))
                }
                .frame(width: Layout.cellWidth, height: Layout.stripHeight)
                .background(slot.period.color)
                .clipped()
            }
        }
    }
}

// MARK: - Now Marker (cell-wide highlight box)

private struct NowMarker: View {
    let offset: CGFloat
    let labelHeight: CGFloat
    let stripHeight: CGFloat
    let rowCount: Int

    private var totalHeight: CGFloat {
        CGFloat(rowCount) * (labelHeight + stripHeight)
    }

    var body: some View {
        let cellW = Layout.cellWidth
        let totalW = CGFloat(Layout.totalSlots) * (cellW + Layout.cellGap)
        let blockH = labelHeight + stripHeight
        // Snap to cell-aligned x (left edge of the hour cell containing offset)
        let cellSpan = cellW + Layout.cellGap
        let snappedX = (cellSpan > 0) ? floor(offset / cellSpan) * cellSpan : offset

        Canvas { context, _ in
            // Full-height black outline box spanning all rows
            let top = labelHeight  // start at first strip
            let lastStripBottom = CGFloat(rowCount - 1) * blockH + labelHeight + stripHeight
            let fullRect = CGRect(x: snappedX, y: top, width: cellW, height: lastStripBottom - top)
            let box = Path(fullRect)
            context.stroke(box, with: .color(.black.opacity(0.8)), lineWidth: 2.5)
        }
        .frame(width: totalW, height: totalHeight)
        .allowsHitTesting(false)
    }
}
