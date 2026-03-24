// WristControlWatch/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var activeControl: ActiveControl = .none
    @State private var brightnessValue: Double = 0.5
    @State private var volumeValue: Double = 0.5
    @State private var isConnected: Bool = false

    private var activeValue: Binding<Double> {
        switch activeControl {
        case .brightness:
            return $brightnessValue
        case .volume:
            return $volumeValue
        case .none, .scroll:
            return .constant(0)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // Connection indicator
                HStack {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(isConnected ? "Conectado" : "Sin conexión")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Control buttons row
                HStack(spacing: 6) {
                    ControlButton(
                        icon: "sun.max.fill",
                        label: "Brillo",
                        isActive: activeControl == .brightness,
                        color: .yellow
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeControl = activeControl == .brightness ? .none : .brightness
                        }
                    }

                    ControlButton(
                        icon: "speaker.wave.2.fill",
                        label: "Vol",
                        isActive: activeControl == .volume,
                        color: .blue
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeControl = activeControl == .volume ? .none : .volume
                        }
                    }

                    ControlButton(
                        icon: "arrow.up.and.down",
                        label: "Scroll",
                        isActive: activeControl == .scroll,
                        color: .green
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeControl = activeControl == .scroll ? .none : .scroll
                        }
                    }
                }

                // Active control view
                if activeControl == .scroll {
                    ScrollCrownView { delta in
                        let command = ControlCommand(type: .scroll, deltaX: 0, deltaY: delta)
                        WatchSessionManager.shared.send(command: command)
                    }
                    .transition(AnyTransition.move(edge: .bottom).combined(with: AnyTransition.opacity))
                } else if activeControl != .none {
                    SliderView(
                        value: activeValue,
                        controlType: activeControl,
                        onChanged: { newValue in
                            sendCommand(value: Float(newValue))
                        }
                    )
                    .transition(AnyTransition.move(edge: .bottom).combined(with: AnyTransition.opacity))
                }

                // Trackpad button
                NavigationLink(destination: WatchTrackpadView()) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 14))
                        Text("Trackpad")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundColor(.purple)
            }
            .onAppear {
                WatchSessionManager.shared.onStatusUpdate = { status in
                    self.brightnessValue = Double(status.brightness)
                    self.volumeValue = Double(status.volume)
                    self.isConnected = status.connected
                }
            }
        }
    }

    private func sendCommand(value: Float) {
        guard activeControl != .none else { return }
        let type: ControlType = activeControl == .brightness ? .brightness : .volume
        let command = ControlCommand(type: type, value: value)
        WatchSessionManager.shared.send(command: command)
    }
}
