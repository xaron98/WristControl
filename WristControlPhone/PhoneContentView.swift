// WristControlPhone/PhoneContentView.swift
import SwiftUI
import Combine

struct PhoneContentView: View {
    @StateObject private var phoneSession = PhoneSessionManager.shared
    @StateObject private var macConnection = MacConnectionManager.shared

    @State private var brightness: Double = 0.5
    @State private var volume: Double = 0.5

    // Throttle state — last time each command was sent
    @State private var lastBrightnessSend: Date = .distantPast
    @State private var lastVolumeSend: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.1  // max 10/sec

    var body: some View {
        VStack(spacing: 24) {
            Text("WristControl")
                .font(.largeTitle.bold())

            // Connection status section
            VStack(spacing: 12) {
                StatusRow(
                    icon: "applewatch",
                    label: "Apple Watch",
                    connected: phoneSession.watchReachable
                )
                StatusRow(
                    icon: "desktopcomputer",
                    label: macConnection.macName,
                    connected: macConnection.isConnected
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

            if !macConnection.isConnected {
                Text("Asegúrate de que WristControl Helper esté abierto en tu Mac y ambos dispositivos estén en la misma red Wi-Fi.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            // Controls section — only shown when connected
            if macConnection.isConnected {
                VStack(spacing: 20) {
                    // Brightness slider
                    ControlSlider(
                        icon: "sun.max.fill",
                        label: "Brightness",
                        value: $brightness,
                        tint: .yellow
                    )
                    .onChange(of: brightness) { newValue in
                        let now = Date()
                        guard now.timeIntervalSince(lastBrightnessSend) >= throttleInterval else { return }
                        lastBrightnessSend = now
                        macConnection.send(command: ControlCommand(type: .brightness, value: Float(newValue)))
                    }

                    Divider()

                    // Volume slider
                    ControlSlider(
                        icon: "speaker.wave.2.fill",
                        label: "Volume",
                        value: $volume,
                        tint: .blue
                    )
                    .onChange(of: volume) { newValue in
                        let now = Date()
                        guard now.timeIntervalSince(lastVolumeSend) >= throttleInterval else { return }
                        lastVolumeSend = now
                        macConnection.send(command: ControlCommand(type: .volume, value: Float(newValue)))
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
            }

            Spacer()
        }
        .padding()
        .onAppear {
            macConnection.startBrowsing()
            phoneSession.onCommandReceived = { command in
                macConnection.send(command: command)
            }
        }
    }
}

// MARK: - ControlSlider

private struct ControlSlider: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(tint)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: 0...1)
                .tint(tint)
        }
    }
}
