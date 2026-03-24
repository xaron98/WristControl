// WristControlMac/SystemActionController.swift
import Foundation
import AppKit
import CoreAudio
import AudioToolbox

class SystemActionController {
    private init() {}

    // MARK: - Media Keys

    static func mediaPlayPause() { postMediaKey(keyCode: 16) }
    static func mediaNext() { postMediaKey(keyCode: 17) }
    static func mediaPrevious() { postMediaKey(keyCode: 18) }

    private static func postMediaKey(keyCode: Int) {
        // Key down
        let keyDown = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: (keyCode << 16) | (0xa << 8),
            data2: -1
        )
        keyDown?.cgEvent?.post(tap: .cghidEventTap)

        let keyUp = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: (keyCode << 16) | (0xb << 8),
            data2: -1
        )
        keyUp?.cgEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Mute Toggle

    static func toggleMute() {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: deviceID))
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var muted: UInt32 = 0
        var mutedSize = UInt32(MemoryLayout.size(ofValue: muted))
        AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &mutedSize, &muted)

        muted = muted == 0 ? 1 : 0
        AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, mutedSize, &muted)
    }

    // MARK: - System Actions

    static func sleepDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    static func lockScreen() {
        // Simulate Cmd+Ctrl+Q (system lock screen shortcut)
        let src = CGEventSource(stateID: .hidSystemState)

        // Key code 12 = "Q"
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 12, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 12, keyDown: false) else { return }

        keyDown.flags = [.maskCommand, .maskControl]
        keyUp.flags = [.maskCommand, .maskControl]

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    static func takeScreenshot() {
        // Simulate Cmd+Shift+3 (system screenshot, no Screen Recording permission needed)
        let src = CGEventSource(stateID: .hidSystemState)

        // Key code 20 = "3"
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 20, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 20, keyDown: false) else { return }

        keyDown.flags = [.maskCommand, .maskShift]
        keyUp.flags = [.maskCommand, .maskShift]

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    static func toggleDarkMode() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell app \"System Events\" to tell appearance preferences to set dark mode to not dark mode"]
        try? process.run()
    }
}
