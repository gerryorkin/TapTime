//
//  TimeText.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI
internal import Combine

// MARK: - Live Time Text
struct TimeText: View {
    let timeZone: TimeZone
    @State private var currentTime = Date()

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formattedTime())
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }

    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: currentTime)
    }
}

// MARK: - Pulsing Dot Animation
struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .fill(.green.opacity(0.3))
                .frame(width: 24, height: 24)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 1)

            // Main dot
            Circle()
                .fill(.green)
                .frame(width: 24, height: 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
