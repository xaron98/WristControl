// WristControlWatch/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var activeControl: ActiveControl = .none
    @State private var brightnessValue: Double = 0.5
    @State private var volumeValue: Double = 0.5
    @State private var isConnected: Bool = false

    var body: some View {
        TabView {
            WatchControlesPage(
                activeControl: $activeControl,
                brightnessValue: $brightnessValue,
                volumeValue: $volumeValue,
                isConnected: isConnected
            )

            WatchTrackpadView()

            WatchAccionesPage()
        }
        .tabViewStyle(.page)
        .onAppear {
            WatchSessionManager.shared.onStatusUpdate = { status in
                self.brightnessValue = Double(status.brightness)
                self.volumeValue = Double(status.volume)
                self.isConnected = status.connected
            }
        }
    }
}
