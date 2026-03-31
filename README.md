# SensorDash

A native macOS SwiftUI app that explores **330+ hardware sensor APIs** across Apple's public, semi-private, and private frameworks. Real-time dashboards with interactive demos for every sensor category.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-green)

## Features

### 9 Sensor Categories

| Tab | Frameworks | Interactive Demos |
|-----|-----------|-------------------|
| **Battery & Power** | IOKit, IOPM (private) | Prevent-sleep toggle, live cell voltage bars, power assertion viewer |
| **Thermal & Fans** | SMC (via IOKit) | CPU stress test ("Heat it up!"), temperature alert threshold, animated fan gauges |
| **Display & Light** | DisplayServices (private) | Real-time brightness slider, preset buttons, smooth 0-100% sweep animation |
| **Trackpad** | MultitouchSupport (private) | Live finger visualization canvas, haptic feedback buttons, drawing mode, gesture logger |
| **HID Sensors** | IOKit IOHIDEvent (semi-private) | Ambient light meter, 38+ event type explorer with availability grid |
| **Motion** | CoreMotion | Accelerometer ball game, shake detector, motion recorder, AirPods head tracking |
| **Proximity / UWB** | CoreBluetooth, Proximity (private) | Live BLE device scanner with RSSI signal bars and distance estimation |
| **Neural Engine** | CoreML, AppleNeuralEngine (private) | Benchmark runner (CPU vs ANE timing), private class discovery |
| **Depth / LiDAR** | AVFoundation, AppleDepth (private) | Camera scanner with depth format discovery |

### Architecture

```
SwiftUI Views (9 detail views + MenuBar)
        |
@Observable ViewModels (DashboardViewModel)
        |
Swift Actor Providers (9 actors, AsyncStream<Reading>)
        |
Bridge Layer (dlopen/dlsym for C, NSClassFromString for ObjC)
        |
IOKit  DisplayServices  MultitouchSupport  IOHIDEvent  CoreMotion
SMC    AppleNeuralEngine  Proximity  AppleDepth  CoreBluetooth
```

- **Private C frameworks** are loaded at runtime via `dlopen`/`dlsym` with `@convention(c)` function pointers
- **Private ObjC frameworks** are accessed via `NSClassFromString` + `performSelector`
- **IOKit services** (SMC, battery) use the public C API with a custom C bridge (`SMCBridge.c`)
- Each sensor provider is a Swift **actor** publishing data via `AsyncStream` for thread safety
- All private framework access gracefully degrades — if a framework or function is unavailable, the UI shows "Not Found" instead of crashing

## Requirements

- macOS 14.0+ (Sonoma or later)
- Apple Silicon (arm64)
- [Xcode](https://developer.apple.com/xcode/) 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & Run

```bash
git clone https://github.com/ayushsdev/SensorDash.git
cd SensorDash
xcodegen generate
open SensorDash.xcodeproj
# Build and run (Cmd+R) in Xcode
```

Or from the command line:

```bash
xcodegen generate
xcodebuild -scheme SensorDash -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/SensorDash-*/Build/Products/Debug/SensorDash.app
```

## Project Structure

```
SensorDash/
├── SensorDashApp.swift              # App entry point (WindowGroup + MenuBarExtra)
├── AppState.swift                   # @Observable root state
├── Bridge/                          # Private framework bridges
│   ├── SMCBridge.c / .h            # C bridge for System Management Controller
│   ├── FrameworkLoader.swift        # Generic dlopen/dlsym utility
│   ├── DisplayServicesBridge.swift  # 30+ DisplayServices function pointers
│   ├── MultitouchBridge.swift       # MultitouchSupport device/contact/actuator APIs
│   ├── IOHIDEventBridge.swift       # 38+ IOHIDEvent types + system client
│   ├── IOPMBridge.swift             # Private IOPM power management functions
│   ├── ProximityBridge.swift        # UWB/Bluetooth proximity classes
│   ├── ANEBridge.swift              # Apple Neural Engine classes
│   ├── CoreMotionBridge.swift       # 33 undocumented CoreMotion classes
│   └── DepthBridge.swift            # AppleDepth LiDAR/stereo depth classes
├── Providers/                       # Async sensor data providers (actors)
│   ├── BatteryProvider.swift        # IOKit registry + IOPM
│   ├── SMCProvider.swift            # SMC temperature/fan/power keys
│   ├── DisplayProvider.swift        # Brightness, ALC, display properties
│   ├── MultitouchProvider.swift     # Live trackpad contact callback
│   ├── HIDEventProvider.swift       # IOHIDEventSystem client
│   ├── MotionProvider.swift         # CMMotionManager + headphone motion
│   ├── ProximityProvider.swift      # UWB chip + class discovery
│   ├── ANEProvider.swift            # Neural Engine device info
│   └── DepthProvider.swift          # Depth framework availability
├── ViewModels/
│   ├── DashboardViewModel.swift     # Connects all providers to UI
│   └── SensorCategory.swift         # 9 category enum + status
├── Views/
│   ├── DashboardView.swift          # NavigationSplitView (sidebar + detail)
│   ├── MenuBarView.swift            # Menubar quick-glance popover
│   ├── Battery/                     # Battery visual, cell voltages, assertions
│   ├── SMC/                         # Temp circles, fan gauges, stress test
│   ├── Display/                     # Brightness control, API explorer
│   ├── Multitouch/                  # Trackpad canvas, haptics, drawing
│   ├── HIDEvent/                    # Event type grid, ALS meter
│   ├── Motion/                      # Ball game, shake detector, attitude
│   ├── Proximity/                   # BLE scanner, signal bars
│   ├── ANE/                         # CoreML benchmark
│   ├── Depth/                       # Camera discovery
│   └── Components/                  # SensorGauge, SparklineChart, UnavailableView
├── SensorDash.entitlements
└── project.yml                      # XcodeGen project definition
```

## Private Frameworks Used

| Framework | Path | APIs |
|-----------|------|------|
| DisplayServices | `/System/Library/PrivateFrameworks/DisplayServices.framework` | Brightness, ALC, display properties |
| MultitouchSupport | `/System/Library/PrivateFrameworks/MultitouchSupport.framework` | Raw trackpad contacts, haptic actuator |
| AppleNeuralEngine | `/System/Library/PrivateFrameworks/AppleNeuralEngine.framework` | ANE device info, client connection |
| Proximity | `/System/Library/PrivateFrameworks/Proximity.framework` | UWB chip, BT ranging, beacons |
| AppleDepth | `/System/Library/PrivateFrameworks/AppleDepth.framework` | Binocular depth, LiDAR |

> **Note:** Private framework APIs are not available in App Store apps. This project is for educational purposes and personal use only. APIs may change or break between macOS versions.

## License

MIT
