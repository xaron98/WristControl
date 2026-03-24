// WristControlPhone/PhoneContentView.swift
import SwiftUI
import Combine

struct PhoneContentView: View {
    @StateObject private var phoneSession = PhoneSessionManager.shared
    @StateObject private var macConnection = MacConnectionManager.shared

    var body: some View {
        TabView {
            ControlesTab(phoneSession: phoneSession, macConnection: macConnection)
                .tabItem {
                    Label("Controles", systemImage: "slider.horizontal.3")
                }

            TrackpadTab(macConnection: macConnection)
                .tabItem {
                    Label("Trackpad", systemImage: "hand.point.up.left")
                }

            AccionesTab(macConnection: macConnection)
                .tabItem {
                    Label("Acciones", systemImage: "bolt.fill")
                }
        }
        .onAppear {
            macConnection.startBrowsing()
            phoneSession.onCommandReceived = { command in
                // Route mouse/scroll through UDP for low latency
                switch command.type {
                case .mouseMove:
                    macConnection.sendFast(type: 0, deltaX: command.deltaX ?? 0, deltaY: command.deltaY ?? 0)
                case .scroll:
                    macConnection.sendFast(type: 1, deltaX: 0, deltaY: command.deltaY ?? command.value)
                default:
                    macConnection.send(command: command)
                }
            }
        }
    }
}

// MARK: - Controles Tab

private struct ControlesTab: View {
    @ObservedObject var phoneSession: PhoneSessionManager
    @ObservedObject var macConnection: MacConnectionManager

    @State private var brightness: Double = 0.5
    @State private var volume: Double = 0.5

    @State private var lastBrightnessSend: Date = .distantPast
    @State private var lastVolumeSend: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.1

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
                        label: "Brillo",
                        value: $brightness,
                        tint: .yellow
                    )
                    .onChange(of: brightness) { _, newValue in
                        let now = Date()
                        guard now.timeIntervalSince(lastBrightnessSend) >= throttleInterval else { return }
                        lastBrightnessSend = now
                        macConnection.send(command: ControlCommand(type: .brightness, value: Float(newValue)))
                    }

                    Divider()

                    // Volume slider
                    ControlSlider(
                        icon: "speaker.wave.2.fill",
                        label: "Volumen",
                        value: $volume,
                        tint: .blue
                    )
                    .onChange(of: volume) { _, newValue in
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
    }
}

// MARK: - Trackpad Tab

private struct TrackpadTab: View {
    @ObservedObject var macConnection: MacConnectionManager

    var body: some View {
        VStack(spacing: 16) {
            // Connection status at top
            VStack(spacing: 8) {
                StatusRow(
                    icon: "desktopcomputer",
                    label: macConnection.macName,
                    connected: macConnection.isConnected
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))

            if macConnection.isConnected {
                TrackpadView(
                    onMove: { dx, dy in
                        macConnection.sendFast(type: 0, deltaX: dx, deltaY: dy)
                    },
                    onClick: {
                        macConnection.send(command: ControlCommand(type: .mouseClick, value: 1))
                    },
                    onRightClick: {
                        macConnection.send(command: ControlCommand(type: .rightClick, value: 1))
                    },
                    onScroll: { dy in
                        macConnection.sendFast(type: 1, deltaX: 0, deltaY: dy)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                Text("Conéctate a tu Mac para usar el trackpad.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }

            Text("1 dedo: mover · Tap: click · 2 dedos: scroll")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .padding()
    }
}

// MARK: - Acciones Tab

private struct AccionesTab: View {
    @ObservedObject var macConnection: MacConnectionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Media
                VStack(spacing: 12) {
                    Text("Multimedia")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 16) {
                        ActionButton(icon: "backward.fill", label: "Anterior") {
                            macConnection.send(command: ControlCommand(type: .mediaPrevious, value: 0))
                        }
                        ActionButton(icon: "play.fill", label: "Play") {
                            macConnection.send(command: ControlCommand(type: .mediaPlayPause, value: 0))
                        }
                        ActionButton(icon: "forward.fill", label: "Siguiente") {
                            macConnection.send(command: ControlCommand(type: .mediaNext, value: 0))
                        }
                    }
                }

                Divider()

                // System
                VStack(spacing: 12) {
                    Text("Sistema")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ActionButton(icon: "speaker.slash.fill", label: "Silenciar") {
                            macConnection.send(command: ControlCommand(type: .mute, value: 0))
                        }
                        ActionButton(icon: "moon.fill", label: "Modo oscuro") {
                            macConnection.send(command: ControlCommand(type: .darkMode, value: 0))
                        }
                        ActionButton(icon: "moon.zzz.fill", label: "Suspender") {
                            macConnection.send(command: ControlCommand(type: .sleep, value: 0))
                        }
                        ActionButton(icon: "lock.fill", label: "Bloquear") {
                            macConnection.send(command: ControlCommand(type: .lockScreen, value: 0))
                        }
                        ActionButton(icon: "camera.fill", label: "Captura") {
                            macConnection.send(command: ControlCommand(type: .screenshot, value: 0))
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

private struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
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
