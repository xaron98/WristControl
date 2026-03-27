# WristControl

Apple Watch + iPhone + Mac app to control Mac brightness, volume, cursor, media, and system actions from the wrist.

## Architecture

Watch ↔ iPhone (WatchConnectivity) ↔ Mac (Bonjour TCP + UDP)

- **TCP** (port 9876): brightness, volume, clicks, system actions, status updates (reliable)
- **UDP** (port 9877): mouse movement, scroll (low latency, 9-byte binary protocol)

## Targets & Distribution

| Target | Platform | Distribution |
|--------|----------|-------------|
| WristControlWatch | watchOS 10.0+ | App Store (embedded in iPhone) |
| WristControlPhone | iOS 17.0+ | App Store |
| WristControlMac | macOS 14.0+ | Developer ID + notarized (no sandbox) |

## Build

```bash
xcodegen generate                    # Regenerate .xcodeproj from project.yml
xcodebuild -scheme WristControlMac   # Build Mac helper
xcodebuild -scheme WristControlPhone # Build iPhone + Watch
```

After `xcodegen generate`, reconfigure signing in Xcode (Signing & Capabilities > Team).

## Key Files

- `Shared/CommandProtocol.swift` — ControlType enum + ControlCommand (shared by all 3 targets)
- `WristControlMac/TCPServer.swift` — TCP + UDP server, command dispatch
- `WristControlMac/SystemActionController.swift` — Media, mute, sleep, lock, screenshot, dark mode
- `WristControlMac/MouseController.swift` — CGEvent cursor control
- `WristControlMac/BrightnessController.swift` — Gamma table brightness (@MainActor)
- `WristControlMac/VolumeController.swift` — CoreAudio volume
- `WristControlPhone/MacConnectionManager.swift` — Bonjour discovery + TCP/UDP client
- `WristControlPhone/TrackpadView.swift` — UIKit raw touch trackpad (120Hz)
- `WristControlWatch/ContentView.swift` — 3-page TabView (.page style)

## Watch UI Structure

3 horizontal swipeable pages:
1. **Controles** — Brillo, Volumen (Crown), Mute, Dark Mode
2. **Trackpad** — Drag to move, tap to click, Crown to scroll
3. **Acciones** — Media (prev/play/next), Sleep, Lock, Screenshot

## iPhone UI Structure

3 tabs:
1. **Controles** — Brightness + Volume sliders
2. **Trackpad** — Touch gestures (1-finger move, tap click, 2-finger scroll)
3. **Acciones** — Media, Silenciar, Modo oscuro, Suspender, Bloquear, Captura

## Skills

Use these Swift skills from `.agents/skills/` when working on this project:

- **swiftui-patterns**: `@Observable` over `ObservableObject`, `@State` for view-local, `@Bindable` for bindings
- **swift-concurrency-6-2**: `@MainActor` for UI, `@concurrent` for background, Approachable Concurrency
- **swift-protocol-di-testing**: Protocol-based DI for testability
- **swift-actor-persistence**: Actors for thread-safe shared state

## Conventions

- UI language: Spanish (all user-facing strings)
- Debug prints wrapped in `#if DEBUG`
- `@MainActor` on BrightnessController and sendCurrentStatus
- Mouse/scroll commands processed on background queue for low latency
- UDP packets validated: `isFinite` guard on all float inputs
- UDP restricted to connected iPhone IP (allowedHost)
- TCP max message size: 64KB guard
- Old TCP connections cancelled on new connection (single-client)
- Mac menu bar: MenuBarExtra (not NSStatusItem) for macOS 26 compatibility
- Brightness: CGSetDisplayTransferByTable (gamma tables, App Store safe)
- Mouse/keyboard: CGEvent (requires Accessibility permission)
- System actions: CGEvent keyboard simulation (screenshot, lock) or Process (sleep, dark mode)
- Privacy policy: https://xaron98.github.io/WristControl/
- Repo: https://github.com/xaron98/WristControl
