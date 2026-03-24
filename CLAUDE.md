# WristControl

Apple Watch + iPhone + Mac app to control Mac brightness, volume, and cursor from the wrist.

## Architecture

Watch ↔ iPhone (WatchConnectivity) ↔ Mac (Bonjour TCP + UDP)

- **TCP** (port 9876): brightness, volume, clicks, status updates (reliable)
- **UDP** (port 9877): mouse movement, scroll (low latency, binary protocol)

## Build

```bash
xcodegen generate                    # Regenerate .xcodeproj from project.yml
xcodebuild -scheme WristControlMac   # Build Mac helper
xcodebuild -scheme WristControlPhone # Build iPhone + Watch
```

After `xcodegen generate`, reconfigure signing in Xcode (Signing & Capabilities > Team).

## Skills

Use these Swift skills from `.agents/skills/` when working on this project:

- **swiftui-patterns**: Use `@Observable` instead of `ObservableObject`, prefer `@State` for view-local state, use `@Bindable` for two-way bindings to `@Observable`
- **swift-concurrency-6-2**: Use `@MainActor` for UI code, `@concurrent` for background work, enable Approachable Concurrency in Xcode 26
- **swift-protocol-di-testing**: Abstract external dependencies (network, system APIs) behind protocols for testability
- **swift-actor-persistence**: Use actors for thread-safe shared state instead of manual locks/DispatchQueues

## Conventions

- Deployment targets: macOS 13.0, iOS 16.0, watchOS 10.0
- Swift 5.9+, SwiftUI for all UI
- Mac helper uses MenuBarExtra (not NSStatusItem) for macOS 26 compatibility
- Brightness uses CGSetDisplayTransferByTable (gamma tables, App Store safe)
- Mouse control uses CGEvent (requires Accessibility permission, no sandbox)
- Mac app distributed outside App Store (Developer ID + notarized)
- Watch + iPhone app goes to App Store
