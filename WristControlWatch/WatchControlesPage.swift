// WristControlWatch/WatchControlesPage.swift
import SwiftUI
import WatchKit

struct WatchControlesPage: View {
    @Binding var activeControl: ActiveControl
    @Binding var brightnessValue: Double
    @Binding var volumeValue: Double
    let isConnected: Bool

    private var activeValue: Binding<Double> {
        switch activeControl {
        case .brightness: return $brightnessValue
        case .volume: return $volumeValue
        case .none: return .constant(0)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(isConnected ? "Conectado" : "Sin conexión")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Row 1: Brightness + Volume
            HStack(spacing: 6) {
                ControlButton(
                    icon: "sun.max.fill", label: "Brillo",
                    isActive: activeControl == .brightness, color: .yellow
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeControl = activeControl == .brightness ? .none : .brightness
                    }
                }
                ControlButton(
                    icon: "speaker.wave.2.fill", label: "Vol",
                    isActive: activeControl == .volume, color: .blue
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeControl = activeControl == .volume ? .none : .volume
                    }
                }
            }

            // Row 2: Mute + Dark Mode
            HStack(spacing: 6) {
                ControlButton(
                    icon: "speaker.slash.fill", label: "Mute",
                    isActive: false, color: .red
                ) {
                    WatchSessionManager.shared.send(command: ControlCommand(type: .mute, value: 0))
                    WKInterfaceDevice.current().play(.click)
                }
                ControlButton(
                    icon: "moon.fill", label: "Dark",
                    isActive: false, color: .indigo
                ) {
                    WatchSessionManager.shared.send(command: ControlCommand(type: .darkMode, value: 0))
                    WKInterfaceDevice.current().play(.click)
                }
            }

            // Active slider
            if activeControl != .none {
                SliderView(
                    value: activeValue,
                    controlType: activeControl,
                    onChanged: { newValue in
                        let type: ControlType = activeControl == .brightness ? .brightness : .volume
                        WatchSessionManager.shared.send(command: ControlCommand(type: type, value: Float(newValue)))
                    }
                )
                .transition(AnyTransition.move(edge: .bottom).combined(with: AnyTransition.opacity))
            }
        }
    }
}
