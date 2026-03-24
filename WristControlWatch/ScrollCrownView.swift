// WristControlWatch/ScrollCrownView.swift
import SwiftUI

struct ScrollCrownView: View {
    let onScroll: (Float) -> Void

    @State private var crownValue: Double = 0.0
    @State private var lastCrownValue: Double = 0.0

    var body: some View {
        VStack(spacing: 8) {
            Text("Scroll")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.green)

            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.green)

            Text("Gira la Crown")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .focusable(true)
        .digitalCrownRotation(
            $crownValue,
            from: -10000.0,
            through: 10000.0,
            by: 1.0,
            sensitivity: .high,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { oldValue, newValue in
            let delta = Float(newValue - lastCrownValue)
            lastCrownValue = newValue

            // Skip if this is a reset
            if abs(delta) > 100 { return }

            if abs(delta) > 0.1 {
                onScroll(delta * 5)
            }

            if abs(crownValue) > 5000 {
                crownValue = 0
                lastCrownValue = 0
            }
        }
    }
}
