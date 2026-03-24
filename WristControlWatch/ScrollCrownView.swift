// WristControlWatch/ScrollCrownView.swift
import SwiftUI

struct ScrollCrownView: View {
    let onScroll: (Float) -> Void

    @State private var crownValue: Double = 0.0
    @State private var lastCrownValue: Double = 0.0
    @State private var lastSentTime: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.05

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
            from: -1000.0,
            through: 1000.0,
            by: 0.5,
            sensitivity: .medium,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { oldValue, newValue in
            let delta = Float(newValue - lastCrownValue)
            lastCrownValue = newValue

            let now = Date()
            guard now.timeIntervalSince(lastSentTime) >= throttleInterval else { return }
            lastSentTime = now

            if abs(delta) > 0.01 {
                onScroll(delta)
            }

            // Reset to center to avoid drift
            if abs(crownValue) > 500 {
                crownValue = 0
                lastCrownValue = 0
            }
        }
    }
}
