// WristControlPhone/StatusRow.swift
import SwiftUI

struct StatusRow: View {
    let icon: String
    let label: String
    let connected: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
            Text(label)
            Spacer()
            Circle()
                .fill(connected ? .green : .red)
                .frame(width: 10, height: 10)
            Text(connected ? "Conectado" : "Desconectado")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
