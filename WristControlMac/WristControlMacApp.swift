// WristControlMac/WristControlMacApp.swift
import SwiftUI
import AppKit

class ServerManager: ObservableObject {
    let server = TCPServer()
    @Published var accessibilityGranted: Bool = false

    init() {
        server.start()
        checkAccessibility()
    }

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        // Try system prompt first
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = trusted

        if !trusted {
            // Open Accessibility settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            // Reveal the app in Finder so user can drag it to the list
            let appPath = Bundle.main.bundleURL
            NSWorkspace.shared.activateFileViewerSelecting([appPath])
        }
    }
}

@main
struct WristControlMacApp: App {
    @StateObject private var serverManager = ServerManager()

    var body: some Scene {
        MenuBarExtra("WristControl", image: "MenuBarIcon") {
            Text("WristControl")
                .font(.headline)

            Divider()

            if serverManager.accessibilityGranted {
                Label("Trackpad activo", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Label("Trackpad requiere permiso", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Button("Conceder acceso de Accesibilidad...") {
                    serverManager.requestAccessibility()
                }
            }

            Divider()

            Button("Salir") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
