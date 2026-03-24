// WristControlWatch/WatchAccionesPage.swift
import SwiftUI
import WatchKit

struct WatchAccionesPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Media row
                HStack(spacing: 6) {
                    ActionBtn(icon: "backward.fill", color: .green) { send(.mediaPrevious) }
                    ActionBtn(icon: "play.fill", color: .green) { send(.mediaPlayPause) }
                    ActionBtn(icon: "forward.fill", color: .green) { send(.mediaNext) }
                }

                // System row
                HStack(spacing: 6) {
                    ActionBtn(icon: "moon.zzz.fill", color: .purple) { send(.sleep) }
                    ActionBtn(icon: "lock.fill", color: .orange) { send(.lockScreen) }
                    ActionBtn(icon: "camera.fill", color: .cyan) { send(.screenshot) }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func send(_ type: ControlType) {
        WatchSessionManager.shared.send(command: ControlCommand(type: type, value: 0))
        WKInterfaceDevice.current().play(.click)
    }
}

private struct ActionBtn: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}
