// WristControlPhone/PhoneContentView.swift
import SwiftUI

struct PhoneContentView: View {
    @StateObject private var phoneSession = PhoneSessionManager.shared
    @StateObject private var macConnection = MacConnectionManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Text("WristControl")
                .font(.largeTitle.bold())

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
