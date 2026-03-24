# WristControl

Control your Mac's brightness, volume, and cursor from your Apple Watch and iPhone.

## Features

| Feature | iPhone | Apple Watch |
|---------|--------|-------------|
| Brightness | Slider | Digital Crown |
| Volume | Slider | Digital Crown |
| Trackpad | Touch gestures | Drag + tap |
| Scroll | Two-finger swipe | Digital Crown |
| Click / Right-click | Tap / Two-finger tap | Tap |

## How It Works

```
Apple Watch ──WatchConnectivity──> iPhone ──TCP/UDP──> Mac Helper
                                  iPhone ──TCP/UDP──> Mac Helper
```

- **Watch <-> iPhone**: Apple's WatchConnectivity framework
- **iPhone -> Mac (controls)**: TCP on port 9876 with Bonjour discovery
- **iPhone -> Mac (mouse/scroll)**: UDP on port 9877 with binary protocol for minimal latency

All communication stays on your local network. No data is sent to any server.

## Requirements

- **Apple Watch**: watchOS 10.0+
- **iPhone**: iOS 17.0+
- **Mac**: macOS 14.0+
- All devices on the same Wi-Fi network

## Setup

### 1. Mac Helper

Run the Mac companion app — it appears as an icon in the menu bar.

On first launch, grant **Accessibility** permission for trackpad control:
- Click the menu bar icon > "Conceder acceso de Accesibilidad..."
- In System Settings, add WristControlMac to the Accessibility list

### 2. iPhone + Watch

Install from the App Store. The Watch app installs automatically when you install the iPhone app.

Open the iPhone app and verify it shows "Conectado" to your Mac.

## Building from Source

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open WristControl.xcodeproj
```

In Xcode, configure signing for all three targets (Signing & Capabilities > your Team), then build and run.

## Architecture

| Component | Target | Distribution |
|-----------|--------|-------------|
| Watch App | watchOS | App Store (embedded in iPhone app) |
| iPhone App | iOS | App Store |
| Mac Helper | macOS | Direct download (Developer ID + notarized) |

### Tech Stack

- **UI**: SwiftUI on all platforms
- **Watch controls**: Digital Crown via `digitalCrownRotation`
- **Networking**: Network.framework (Bonjour + TCP/UDP)
- **Brightness**: `CGSetDisplayTransferByTable` (gamma tables)
- **Volume**: CoreAudio (`AudioObjectSetPropertyData`)
- **Mouse/Scroll**: `CGEvent` (requires Accessibility permission)

## Privacy

WristControl does not collect, store, or transmit any personal data. All communication is local-only between your own devices.

[Privacy Policy](https://xaron98.github.io/WristControl/)

## License

All rights reserved.
