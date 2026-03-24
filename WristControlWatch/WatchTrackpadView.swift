// WristControlWatch/WatchTrackpadView.swift
import SwiftUI
import WatchKit

struct WatchTrackpadView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var scrollValue: Double = 0.0
    @State private var lastScrollValue: Double = 0.0
    @State private var lastDragLocation: CGPoint? = nil
    @State private var lastSendTime: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.03  // ~30fps max for WatchConnectivity

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Trackpad surface
                Color.black.opacity(0.01)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                if let last = lastDragLocation {
                                    let rawDX = Float(value.location.x - last.x)
                                    let rawDY = Float(value.location.y - last.y)
                                    let dx = accelerate(rawDX)
                                    let dy = accelerate(rawDY)
                                    if abs(dx) > 0.01 || abs(dy) > 0.01 {
                                        let now = Date()
                                        guard now.timeIntervalSince(lastSendTime) >= throttleInterval else {
                                            lastDragLocation = value.location
                                            return
                                        }
                                        lastSendTime = now
                                        let command = ControlCommand(type: .mouseMove, deltaX: dx, deltaY: dy)
                                        WatchSessionManager.shared.send(command: command)
                                    }
                                }
                                lastDragLocation = value.location
                            }
                            .onEnded { _ in
                                lastDragLocation = nil
                            }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                let command = ControlCommand(type: .mouseClick, value: 1)
                                WatchSessionManager.shared.send(command: command)
                                WKInterfaceDevice.current().play(.click)
                            }
                    )

                // Visual overlay
                VStack(spacing: 4) {
                    Spacer()
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Arrastra · Tap = click")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Crown = desplazar")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.15))
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .focusable(true)
        .digitalCrownRotation(
            $scrollValue,
            from: -10000.0,
            through: 10000.0,
            by: 1.0,
            sensitivity: .high,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: scrollValue) { _, newValue in
            let delta = Float(newValue - lastScrollValue)
            lastScrollValue = newValue

            // Skip if this is a reset
            if abs(delta) > 100 { return }

            if abs(delta) > 0.1 {
                let command = ControlCommand(type: .scroll, deltaX: 0, deltaY: delta * 5)
                WatchSessionManager.shared.send(command: command)
            }

            if abs(scrollValue) > 5000 {
                scrollValue = 0
                lastScrollValue = 0
            }
        }
        .navigationTitle("Trackpad")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Same smooth acceleration as iPhone
    private func accelerate(_ delta: Float) -> Float {
        let magnitude = abs(delta)
        let base: Float = 1.5
        let scale: Float = 0.2
        let power: Float = 0.8
        let multiplier = base + scale * pow(magnitude, power)
        return delta * multiplier
    }
}
