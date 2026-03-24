// WristControlMac/WristControlMacApp.swift
import SwiftUI

@main
struct WristControlMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var server: TCPServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "applewatch", accessibilityDescription: "WristControl")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "WristControl Activo", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Salir",
            action: #selector(quit),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu

        server = TCPServer()
        server.start()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
