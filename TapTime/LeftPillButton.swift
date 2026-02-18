//
//  LeftPillButton.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI

struct LeftPillButton: View {
    let icon: String
    let label: String
    let isLarge: Bool
    let action: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width
            let collapsedOffset = -(cardWidth * 0.70)  // 70% off-screen to the left (30% visible)

            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: isLarge ? 16 : 14))
            }
            .padding(.horizontal, isLarge ? 20 : 16)
            .padding(.vertical, isLarge ? 10 : 6)
            .frame(width: cardWidth)
            .background(
                Color.white.opacity(0.5)
                    .background(.ultraThinMaterial)
            )
            .foregroundColor(.black)
            .clipShape(isLarge ? AnyShape(RoundedRectangle(cornerRadius: 16)) : AnyShape(Capsule()))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .offset(x: collapsedOffset)
            .onTapGesture {
                action()
            }
        }
        .frame(height: isLarge ? 44 : 32)
    }
}
