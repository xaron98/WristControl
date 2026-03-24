// WristControlWatch/WatchTrackpadView.swift
import SwiftUI
import WatchKit

struct WatchTrackpadView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var scrollValue: Double = 0.0
    @State private var lastScrollValue: Double = 0.0

    private let sensitivity: Float = 3.0
    @State private var lastDragLocation: CGPoint? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Trackpad surface
                Color.black.opacity(0.01)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .local)
                            .onChanged { value in
                                if let last = lastDragLocation {
                                    let dx = Float(value.location.x - last.x) * sensitivity
                                    let dy = Float(value.location.y - last.y) * sensitivity
                                    let command = ControlCommand(type: .mouseMove, deltaX: dx, deltaY: dy)
                                    WatchSessionManager.shared.send(command: command)
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
                VStack(spacing: 6) {
                    Spacer()

                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))

                    Text("Arrastra para mover")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))

                    Text("Tap = click · Crown = scroll")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.2))

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
        .onChange(of: scrollValue) { oldValue, newValue in
            let delta = Float(newValue - lastScrollValue)
            lastScrollValue = newValue
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
}
