// WristControlMac/WristControlMacApp.swift
import SwiftUI

class ServerManager: ObservableObject {
    let server = TCPServer()

    init() {
        server.start()
    }
}

@main
struct WristControlMacApp: App {
    @StateObject private var serverManager = ServerManager()

    var body: some Scene {
        MenuBarExtra("WristControl", image: "MenuBarIcon") {
            Text("WristControl Activo")
                .font(.headline)
            Divider()
            Button("Salir") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
