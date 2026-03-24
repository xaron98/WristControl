# WristControl Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Apple Watch app (+ iPhone bridge + macOS helper) to control Mac brightness and volume via Digital Crown.

**Architecture:** Three-component system — watchOS UI sends commands via WatchConnectivity to iPhone, which bridges via Bonjour/TCP to a macOS menu bar helper that applies brightness (CoreDisplay) and volume (CoreAudio) changes. Controls are mutually exclusive (brightness OR volume active at a time).

**Tech Stack:** Swift, SwiftUI, WatchKit, WatchConnectivity, Network.framework (Bonjour/TCP), CoreAudio, CoreDisplay, xcodegen for project generation.

---

## File Structure

```
WristControl/
├── project.yml                          # xcodegen project spec
├── Shared/
│   └── CommandProtocol.swift            # ControlCommand + StatusUpdate models
├── WristControlWatch/
│   ├── WristControlWatchApp.swift       # watchOS app entry point
│   ├── ContentView.swift                # Main view: 2 buttons + slider
│   ├── ControlButton.swift              # Reusable button component
│   ├── SliderView.swift                 # Digital Crown slider with throttle
│   ├── WatchSessionManager.swift        # WCSession delegate (Watch side)
│   ├── Assets.xcassets/
│   │   └── AccentColor.colorset/
│   │       └── Contents.json
│   └── Info.plist
├── WristControlPhone/
│   ├── WristControlPhoneApp.swift       # iOS app entry point
│   ├── PhoneContentView.swift           # Status display UI
│   ├── StatusRow.swift                  # Connection status row component
│   ├── PhoneSessionManager.swift        # WCSession delegate (Phone side)
│   ├── MacConnectionManager.swift       # Bonjour browser + TCP client
│   ├── Assets.xcassets/
│   │   └── AccentColor.colorset/
│   │       └── Contents.json
│   └── Info.plist
├── WristControlMac/
│   ├── WristControlMacApp.swift         # macOS app entry + AppDelegate
│   ├── TCPServer.swift                  # Bonjour advertiser + TCP listener
│   ├── BrightnessController.swift       # CoreDisplay brightness control
│   ├── VolumeController.swift           # CoreAudio volume control
│   ├── Assets.xcassets/
│   │   └── AccentColor.colorset/
│   │       └── Contents.json
│   ├── Info.plist
│   └── WristControlMac.entitlements
├── SharedTests/
│   └── CommandProtocolTests.swift       # Tests for shared models
└── docs/
    └── superpowers/
        └── plans/
            └── 2026-03-24-wristcontrol.md
```

---

### Task 1: Project Scaffold — Directory Structure

**Files:**
- Create: all directories listed in file structure above

- [ ] **Step 1: Create directory tree**

```bash
mkdir -p WristControlWatch/Assets.xcassets/AccentColor.colorset
mkdir -p WristControlPhone/Assets.xcassets/AccentColor.colorset
mkdir -p WristControlMac/Assets.xcassets/AccentColor.colorset
mkdir -p Shared
mkdir -p SharedTests
```

- [ ] **Step 2: Create asset catalog Contents.json files**

Each `Assets.xcassets` needs a `Contents.json`, and each `AccentColor.colorset` needs one too.

`WristControlWatch/Assets.xcassets/Contents.json`, `WristControlPhone/Assets.xcassets/Contents.json`, `WristControlMac/Assets.xcassets/Contents.json`:
```json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

`*/AccentColor.colorset/Contents.json` (all three):
```json
{
  "colors": [
    {
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

- [ ] **Step 3: Create .gitignore**

```gitignore
# Xcode
build/
DerivedData/
*.xcuserdata
xcuserdata/

# macOS
.DS_Store

# Swift Package Manager
.build/
Packages/
Package.resolved
```

- [ ] **Step 4: Commit**

```bash
git init
git add -A
git commit -m "chore: scaffold WristControl directory structure with .gitignore"
```

---

### Task 2: Shared Protocol — CommandProtocol.swift

**Files:**
- Create: `Shared/CommandProtocol.swift`
- Create: `SharedTests/CommandProtocolTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// SharedTests/CommandProtocolTests.swift
import XCTest
@testable import WristControlPhone // Will import Shared via target membership

final class CommandProtocolTests: XCTestCase {

    func testControlCommandEncodeDecode() throws {
        let command = ControlCommand(type: .brightness, value: 0.75)
        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(ControlCommand.self, from: data)
        XCTAssertEqual(decoded.type, .brightness)
        XCTAssertEqual(decoded.value, 0.75, accuracy: 0.001)
    }

    func testControlCommandDictionaryRoundTrip() {
        let command = ControlCommand(type: .volume, value: 0.5)
        let dict = command.dictionaryRepresentation
        let restored = ControlCommand.from(dictionary: dict)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.type, .volume)
        XCTAssertEqual(restored?.value ?? 0, 0.5, accuracy: 0.001)
    }

    func testControlCommandFromInvalidDictionary() {
        let bad: [String: Any] = ["type": "invalid", "value": 0.5]
        XCTAssertNil(ControlCommand.from(dictionary: bad))

        let missing: [String: Any] = ["type": "brightness"]
        XCTAssertNil(ControlCommand.from(dictionary: missing))
    }

    func testStatusUpdateEncodeDecode() throws {
        let status = StatusUpdate(brightness: 0.8, volume: 0.3, connected: true)
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(StatusUpdate.self, from: data)
        XCTAssertEqual(decoded.brightness, 0.8, accuracy: 0.001)
        XCTAssertEqual(decoded.volume, 0.3, accuracy: 0.001)
        XCTAssertTrue(decoded.connected)
    }
}
```

- [ ] **Step 2: Write the implementation**

```swift
// Shared/CommandProtocol.swift
import Foundation

enum ControlType: String, Codable {
    case brightness
    case volume
}

struct ControlCommand: Codable {
    let type: ControlType
    let value: Float  // 0.0 ... 1.0

    var dictionaryRepresentation: [String: Any] {
        return [
            "type": type.rawValue,
            "value": value
        ]
    }

    static func from(dictionary: [String: Any]) -> ControlCommand? {
        guard
            let typeRaw = dictionary["type"] as? String,
            let type = ControlType(rawValue: typeRaw),
            let value = dictionary["value"] as? Float
        else { return nil }
        return ControlCommand(type: type, value: value)
    }
}

struct StatusUpdate: Codable {
    let brightness: Float
    let volume: Float
    let connected: Bool
}
```

- [ ] **Step 3: Commit**

```bash
git add Shared/CommandProtocol.swift SharedTests/CommandProtocolTests.swift
git commit -m "feat: add shared CommandProtocol with ControlCommand and StatusUpdate models"
```

---

### Task 3: macOS Helper — BrightnessController

**Files:**
- Create: `WristControlMac/BrightnessController.swift`

- [ ] **Step 1: Write BrightnessController**

```swift
// WristControlMac/BrightnessController.swift
import Foundation
import CoreGraphics

class BrightnessController {

    static func setBrightness(_ value: Float) {
        let clamped = min(max(value, 0.0), 1.0)
        CoreDisplay_Display_SetUserBrightness(CGMainDisplayID(), Double(clamped))
    }

    static func getBrightness() -> Float {
        let brightness = CoreDisplay_Display_GetUserBrightness(CGMainDisplayID())
        return Float(brightness)
    }
}

// CoreDisplay private framework declarations
@_silgen_name("CoreDisplay_Display_SetUserBrightness")
func CoreDisplay_Display_SetUserBrightness(_ display: CGDirectDisplayID, _ brightness: Double)

@_silgen_name("CoreDisplay_Display_GetUserBrightness")
func CoreDisplay_Display_GetUserBrightness(_ display: CGDirectDisplayID) -> Double
```

- [ ] **Step 2: Commit**

```bash
git add WristControlMac/BrightnessController.swift
git commit -m "feat(mac): add BrightnessController with CoreDisplay integration"
```

---

### Task 4: macOS Helper — VolumeController

**Files:**
- Create: `WristControlMac/VolumeController.swift`

- [ ] **Step 1: Write VolumeController**

```swift
// WristControlMac/VolumeController.swift
import Foundation
import CoreAudio
import AudioToolbox

class VolumeController {

    static func setVolume(_ value: Float) {
        let clamped = min(max(value, 0.0), 1.0)

        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))

        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultOutputDevicePropertyAddress,
            0, nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )

        var volume = Float32(clamped)
        let volumeSize = UInt32(MemoryLayout.size(ofValue: volume))

        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &volumePropertyAddress,
            0, nil,
            volumeSize,
            &volume
        )
    }

    static func getVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))

        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultOutputDevicePropertyAddress,
            0, nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )

        var volume = Float32(0.0)
        var volumeSize = UInt32(MemoryLayout.size(ofValue: volume))

        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &volumePropertyAddress,
            0, nil,
            &volumeSize,
            &volume
        )

        return volume
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add WristControlMac/VolumeController.swift
git commit -m "feat(mac): add VolumeController with CoreAudio integration"
```

---

### Task 5: macOS Helper — TCPServer (Bonjour + TCP)

**Files:**
- Create: `WristControlMac/TCPServer.swift`

- [ ] **Step 1: Write TCPServer**

```swift
// WristControlMac/TCPServer.swift
import Foundation
import Network

class TCPServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    private let serviceType = "_wristcontrol._tcp"
    private let port: UInt16 = 9876

    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.service = NWListener.Service(
                name: Host.current().localizedName ?? "Mac",
                type: serviceType
            )

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    print("[WristControl] Server ready on port \(self.port)")
                case .failed(let error):
                    print("[WristControl] Server failed: \(error)")
                default:
                    break
                }
            }

            listener?.start(queue: .main)
        } catch {
            print("[WristControl] Error creating listener: \(error)")
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        print("[WristControl] New connection from iPhone")
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(from: connection)
            case .failed, .cancelled:
                self?.connections.removeAll { $0 === connection }
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInteractive))
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            connection.receive(
                minimumIncompleteLength: Int(length),
                maximumLength: Int(length)
            ) { payload, _, _, error in
                if let payload = payload,
                   let command = try? JSONDecoder().decode(ControlCommand.self, from: payload) {
                    self.handleCommand(command, connection: connection)
                }
                self.receiveData(from: connection)
            }
        }
    }

    private func handleCommand(_ command: ControlCommand, connection: NWConnection) {
        if command.value < 0 {
            sendCurrentStatus(to: connection)
            return
        }

        DispatchQueue.main.async {
            switch command.type {
            case .brightness:
                BrightnessController.setBrightness(command.value)
            case .volume:
                VolumeController.setVolume(command.value)
            }
            self.sendCurrentStatus(to: connection)
        }
    }

    private func sendCurrentStatus(to connection: NWConnection) {
        let status = StatusUpdate(
            brightness: BrightnessController.getBrightness(),
            volume: VolumeController.getVolume(),
            connected: true
        )

        guard let data = try? JSONEncoder().encode(status) else { return }

        var length = UInt32(data.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)

        connection.send(content: lengthData + data, completion: .contentProcessed { error in
            if let error = error {
                print("[WristControl] Error sending status: \(error)")
            }
        })
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add WristControlMac/TCPServer.swift
git commit -m "feat(mac): add TCPServer with Bonjour advertising and TCP listener"
```

---

### Task 6: macOS Helper — App Entry Point

**Files:**
- Create: `WristControlMac/WristControlMacApp.swift`

- [ ] **Step 1: Write WristControlMacApp**

```swift
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
```

- [ ] **Step 2: Commit**

```bash
git add WristControlMac/WristControlMacApp.swift
git commit -m "feat(mac): add menu bar app entry point with AppDelegate"
```

---

### Task 7: macOS Helper — Info.plist + Entitlements

**Files:**
- Create: `WristControlMac/Info.plist`
- Create: `WristControlMac/WristControlMac.entitlements`

- [ ] **Step 1: Write Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSBonjourServices</key>
    <array>
        <string>_wristcontrol._tcp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>WristControl necesita acceso a la red local para comunicarse con tu iPhone.</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Write entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 3: Commit**

```bash
git add WristControlMac/Info.plist WristControlMac/WristControlMac.entitlements
git commit -m "feat(mac): add Info.plist with Bonjour config and sandbox entitlements"
```

---

### Task 8: iPhone — PhoneSessionManager (WatchConnectivity)

**Files:**
- Create: `WristControlPhone/PhoneSessionManager.swift`

- [ ] **Step 1: Write PhoneSessionManager**

```swift
// WristControlPhone/PhoneSessionManager.swift
import Foundation
import WatchConnectivity

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    @Published var lastCommand: ControlCommand?
    @Published var watchReachable: Bool = false

    var onCommandReceived: ((ControlCommand) -> Void)?

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendStatus(_ status: StatusUpdate) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "brightness": status.brightness,
            "volume": status.volume,
            "connected": status.connected
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            print("[WristControl] Error sending status to Watch: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.watchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.watchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let command = ControlCommand.from(dictionary: message) {
            DispatchQueue.main.async {
                self.lastCommand = command
                self.onCommandReceived?(command)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add WristControlPhone/PhoneSessionManager.swift
git commit -m "feat(phone): add PhoneSessionManager for Watch↔Phone bridge"
```

---

### Task 9: iPhone — MacConnectionManager (Bonjour + TCP)

**Files:**
- Create: `WristControlPhone/MacConnectionManager.swift`

- [ ] **Step 1: Write MacConnectionManager**

```swift
// WristControlPhone/MacConnectionManager.swift
import Foundation
import Network

class MacConnectionManager: ObservableObject {
    static let shared = MacConnectionManager()

    @Published var isConnected: Bool = false
    @Published var macName: String = "Buscando..."

    private var connection: NWConnection?
    private var browser: NWBrowser?

    private let serviceType = "_wristcontrol._tcp"

    func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(
            for: .bonjour(type: serviceType, domain: nil),
            using: parameters
        )

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }

            if let result = results.first {
                switch result.endpoint {
                case .service(let name, _, _, _):
                    DispatchQueue.main.async {
                        self.macName = name
                    }
                    self.connectToMac(endpoint: result.endpoint)
                default:
                    break
                }
            }
        }

        browser?.stateUpdateHandler = { state in
            print("[WristControl] Browser state: \(state)")
        }

        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func connectToMac(endpoint: NWEndpoint) {
        connection?.cancel()

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.requestCurrentStatus()
                case .failed, .cancelled:
                    self?.isConnected = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.startBrowsing()
                    }
                default:
                    break
                }
            }
        }

        connection?.start(queue: .global(qos: .userInteractive))
        receiveData()
    }

    func send(command: ControlCommand) {
        guard let connection = connection else { return }

        do {
            let data = try JSONEncoder().encode(command)
            var length = UInt32(data.count).bigEndian
            let lengthData = Data(bytes: &length, count: 4)

            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error = error {
                    print("[WristControl] Error sending to Mac: \(error.localizedDescription)")
                }
            })
        } catch {
            print("[WristControl] Error encoding command: \(error)")
        }
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data else { return }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            self.connection?.receive(
                minimumIncompleteLength: Int(length),
                maximumLength: Int(length)
            ) { payload, _, _, error in
                if let payload = payload,
                   let status = try? JSONDecoder().decode(StatusUpdate.self, from: payload) {
                    DispatchQueue.main.async {
                        PhoneSessionManager.shared.sendStatus(status)
                    }
                }
                self.receiveData()
            }
        }
    }

    private func requestCurrentStatus() {
        let request = ControlCommand(type: .brightness, value: -1)
        send(command: request)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add WristControlPhone/MacConnectionManager.swift
git commit -m "feat(phone): add MacConnectionManager with Bonjour discovery and TCP client"
```

---

### Task 10: iPhone — UI and App Entry Point

**Files:**
- Create: `WristControlPhone/StatusRow.swift`
- Create: `WristControlPhone/PhoneContentView.swift`
- Create: `WristControlPhone/WristControlPhoneApp.swift`

- [ ] **Step 1: Write StatusRow**

```swift
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
```

- [ ] **Step 2: Write PhoneContentView**

```swift
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
```

- [ ] **Step 3: Write WristControlPhoneApp**

```swift
// WristControlPhone/WristControlPhoneApp.swift
import SwiftUI

@main
struct WristControlPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            PhoneContentView()
        }
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add WristControlPhone/StatusRow.swift WristControlPhone/PhoneContentView.swift WristControlPhone/WristControlPhoneApp.swift
git commit -m "feat(phone): add iPhone companion UI with connection status display"
```

---

### Task 11: iPhone — Info.plist

**Files:**
- Create: `WristControlPhone/Info.plist`

- [ ] **Step 1: Write Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSBonjourServices</key>
    <array>
        <string>_wristcontrol._tcp</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>WristControl necesita acceso a la red local para conectarse a tu Mac.</string>
</dict>
</plist>
```

- [ ] **Step 2: Commit**

```bash
git add WristControlPhone/Info.plist
git commit -m "feat(phone): add Info.plist with Bonjour config"
```

---

### Task 12: Watch — WatchSessionManager

**Files:**
- Create: `WristControlWatch/WatchSessionManager.swift`

- [ ] **Step 1: Write WatchSessionManager**

```swift
// WristControlWatch/WatchSessionManager.swift
import Foundation
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    var onStatusUpdate: ((StatusUpdate) -> Void)?

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func send(command: ControlCommand) {
        guard let session = session, session.isReachable else {
            print("[WristControl] iPhone not reachable")
            return
        }

        session.sendMessage(
            command.dictionaryRepresentation,
            replyHandler: nil,
            errorHandler: { error in
                print("[WristControl] Error sending command: \(error.localizedDescription)")
            }
        )
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[WristControl] WCSession activation error: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let brightnessVal = message["brightness"] as? Float,
           let volumeVal = message["volume"] as? Float,
           let connected = message["connected"] as? Bool {
            let status = StatusUpdate(
                brightness: brightnessVal,
                volume: volumeVal,
                connected: connected
            )
            DispatchQueue.main.async {
                self.onStatusUpdate?(status)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add WristControlWatch/WatchSessionManager.swift
git commit -m "feat(watch): add WatchSessionManager for Watch↔Phone communication"
```

---

### Task 13: Watch — UI Components

**Files:**
- Create: `WristControlWatch/ControlButton.swift`
- Create: `WristControlWatch/SliderView.swift`

- [ ] **Step 1: Write ControlButton**

```swift
// WristControlWatch/ControlButton.swift
import SwiftUI

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isActive ? color : .gray)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? color : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? color.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Write SliderView**

```swift
// WristControlWatch/SliderView.swift
import SwiftUI

enum ActiveControl: String {
    case none
    case brightness
    case volume
}

struct SliderView: View {
    @Binding var value: Double
    let controlType: ActiveControl
    let onChanged: (Double) -> Void

    @State private var lastSentTime: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.1

    private var icon: String {
        controlType == .brightness ? "sun.max.fill" : "speaker.wave.2.fill"
    }

    private var color: Color {
        controlType == .brightness ? .yellow : .blue
    }

    private var percentage: Int {
        Int(value * 100)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("\(percentage)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, geometry.size.width * CGFloat(value)),
                            height: 12
                        )
                }
            }
            .frame(height: 12)

            HStack {
                Image(systemName: controlType == .brightness ? "sun.min" : "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: controlType == .brightness ? "sun.max.fill" : "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .focusable(true)
        .digitalCrownRotation(
            $value,
            from: 0.0,
            through: 1.0,
            by: 0.02,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: value) { oldValue, newValue in
            let clampedValue = min(max(newValue, 0.0), 1.0)
            if clampedValue != newValue {
                value = clampedValue
            }
            throttledSend(clampedValue)
        }
    }

    private func throttledSend(_ newValue: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastSentTime) >= throttleInterval else { return }
        lastSentTime = now
        onChanged(newValue)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add WristControlWatch/ControlButton.swift WristControlWatch/SliderView.swift
git commit -m "feat(watch): add ControlButton and SliderView UI components with Digital Crown support"
```

---

### Task 14: Watch — ContentView and App Entry Point

**Files:**
- Create: `WristControlWatch/ContentView.swift`
- Create: `WristControlWatch/WristControlWatchApp.swift`
- Create: `WristControlWatch/Info.plist`

- [ ] **Step 1: Write ContentView**

```swift
// WristControlWatch/ContentView.swift
import SwiftUI

struct ContentView: View {
    @State private var activeControl: ActiveControl = .none
    @State private var brightnessValue: Double = 0.5
    @State private var volumeValue: Double = 0.5
    @State private var isConnected: Bool = false

    private var activeValue: Binding<Double> {
        switch activeControl {
        case .brightness:
            return $brightnessValue
        case .volume:
            return $volumeValue
        case .none:
            return .constant(0)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Conectado" : "Sin conexión")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                ControlButton(
                    icon: "sun.max.fill",
                    label: "Brillo",
                    isActive: activeControl == .brightness,
                    color: .yellow
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeControl = activeControl == .brightness ? .none : .brightness
                    }
                }

                ControlButton(
                    icon: "speaker.wave.2.fill",
                    label: "Volumen",
                    isActive: activeControl == .volume,
                    color: .blue
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeControl = activeControl == .volume ? .none : .volume
                    }
                }
            }

            if activeControl != .none {
                SliderView(
                    value: activeValue,
                    controlType: activeControl,
                    onChanged: { newValue in
                        sendCommand(value: Float(newValue))
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            WatchSessionManager.shared.onStatusUpdate = { status in
                self.brightnessValue = Double(status.brightness)
                self.volumeValue = Double(status.volume)
                self.isConnected = status.connected
            }
        }
    }

    private func sendCommand(value: Float) {
        guard activeControl != .none else { return }
        let type: ControlType = activeControl == .brightness ? .brightness : .volume
        let command = ControlCommand(type: type, value: value)
        WatchSessionManager.shared.send(command: command)
    }
}
```

- [ ] **Step 2: Write WristControlWatchApp**

```swift
// WristControlWatch/WristControlWatchApp.swift
import SwiftUI

@main
struct WristControlWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 3: Write Watch Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>WKApplication</key>
    <true/>
    <key>WKCompanionAppBundleIdentifier</key>
    <string>com.xaron.wristcontrol.phone</string>
</dict>
</plist>
```

- [ ] **Step 4: Commit**

```bash
git add WristControlWatch/ContentView.swift WristControlWatch/WristControlWatchApp.swift WristControlWatch/Info.plist
git commit -m "feat(watch): add ContentView with dual-control UI and app entry point"
```

---

### Task 15: xcodegen Project Spec

**Files:**
- Create: `project.yml`

- [ ] **Step 1: Write project.yml**

This is the xcodegen spec that ties all 3 targets together. The Watch app is embedded in the iPhone app (required by Apple). The Mac app is a standalone target.

```yaml
name: WristControl
options:
  bundleIdPrefix: com.xaron.wristcontrol
  deploymentTarget:
    watchOS: "10.0"
    iOS: "16.0"
    macOS: "13.0"
  xcodeVersion: "16.0"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: 1

targets:
  WristControlPhone:
    type: application
    platform: iOS
    sources:
      - path: WristControlPhone
      - path: Shared
    info:
      path: WristControlPhone/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.xaron.wristcontrol.phone
    dependencies:
      - target: WristControlWatch
        embed: true

  WristControlWatch:
    type: application
    platform: watchOS
    sources:
      - path: WristControlWatch
      - path: Shared
    info:
      path: WristControlWatch/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.xaron.wristcontrol.phone.watchkitapp

  WristControlMac:
    type: application
    platform: macOS
    sources:
      - path: WristControlMac
      - path: Shared
    info:
      path: WristControlMac/Info.plist
    entitlements:
      path: WristControlMac/WristControlMac.entitlements
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.xaron.wristcontrol.mac
    frameworks:
      - CoreAudio
      - AudioToolbox

  SharedTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: SharedTests
    dependencies:
      - target: WristControlPhone
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.xaron.wristcontrol.sharedtests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/WristControlPhone.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WristControlPhone"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

- [ ] **Step 2: Commit**

```bash
git add project.yml
git commit -m "feat: add xcodegen project.yml with all 3 targets and test target"
```

---

### Task 16: Generate Xcode Project and Verify Build

**Files:**
- Generate: `WristControl.xcodeproj/` (via xcodegen)

- [ ] **Step 1: Run xcodegen**

```bash
cd /Users/xaron/Desktop/CMac
xcodegen generate
```

Expected: "Generated project WristControl.xcodeproj"

- [ ] **Step 2: Build macOS target**

```bash
xcodebuild -project WristControl.xcodeproj -scheme WristControlMac -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: "BUILD SUCCEEDED"

- [ ] **Step 3: Build iOS target**

```bash
xcodebuild -project WristControl.xcodeproj -scheme WristControlPhone -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: "BUILD SUCCEEDED"

- [ ] **Step 4: Build watchOS target**

```bash
xcodebuild -project WristControl.xcodeproj -scheme WristControlWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build 2>&1 | tail -5
```

Expected: "BUILD SUCCEEDED"

- [ ] **Step 5: Run tests**

```bash
xcodebuild -project WristControl.xcodeproj -scheme SharedTests -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -10
```

Expected: "TEST SUCCEEDED" — all 4 test cases pass.

- [ ] **Step 6: Commit generated project**

```bash
git add WristControl.xcodeproj
git commit -m "chore: generate Xcode project via xcodegen"
```

---

## Execution Order Summary

| Task | Component | Description |
|------|-----------|-------------|
| 1 | Scaffold | Directory structure + .gitignore + asset catalogs |
| 2 | Shared | CommandProtocol models + tests |
| 3 | Mac | BrightnessController |
| 4 | Mac | VolumeController |
| 5 | Mac | TCPServer (Bonjour + TCP) |
| 6 | Mac | App entry point (menu bar) |
| 7 | Mac | Info.plist + entitlements |
| 8 | Phone | PhoneSessionManager |
| 9 | Phone | MacConnectionManager |
| 10 | Phone | UI + app entry point |
| 11 | Phone | Info.plist |
| 12 | Watch | WatchSessionManager |
| 13 | Watch | UI components (ControlButton + SliderView) |
| 14 | Watch | ContentView + app entry point + Info.plist |
| 15 | Build | xcodegen project.yml |
| 16 | Build | Generate project + verify all builds |

**Tasks 3-7 (Mac), 8-11 (Phone), 12-14 (Watch) are independent** and can be parallelized across agents. Tasks 15-16 depend on all prior tasks.
