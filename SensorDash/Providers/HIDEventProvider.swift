import Foundation

actor HIDEventProvider {
    struct Reading: Sendable {
        let ambientLightLux: Double?
        let accelerometerX: Double?
        let accelerometerY: Double?
        let accelerometerZ: Double?
        let gyroX: Double?
        let gyroY: Double?
        let gyroZ: Double?
        let compassX: Double?
        let compassY: Double?
        let compassZ: Double?
        let atmosphericPressure: Double?
        let brightnessLevel: Double?
        let frameworkLoaded: Bool
        let availableEventTypes: [String]
        let timestamp: Date
    }

    private var isRunning = false
    private var client: UnsafeMutableRawPointer?
    private let queue = DispatchQueue(label: "com.sensordash.hid", qos: .userInteractive)

    func start() -> AsyncStream<Reading> {
        isRunning = true
        return AsyncStream { continuation in
            Task { [weak self] in
                guard let self else { return }

                // Try to set up IOHIDEventSystemClient for ALS
                await self.setupEventClient()

                while await self.isRunning {
                    let reading = await self.readEvents()
                    continuation.yield(reading)
                    try? await Task.sleep(for: .seconds(1))
                }
                await self.teardownEventClient()
                continuation.finish()
            }
        }
    }

    func stop() { isRunning = false }

    private func setupEventClient() {
        // IOHIDEventSystemClient requires elevated privileges on modern macOS.
        // Skip setup to avoid crashes — report API availability instead.
        guard HIDEventBridge.isLoaded, HIDEventBridge.createClient != nil else { return }
        // NOTE: Uncomment below if running with root or special entitlements:
        // client = HIDEventBridge.createClient?(kCFAllocatorDefault)
        // guard let client else { return }
        // let matching: [String: Any] = [
        //     "PrimaryUsagePage": HIDEventBridge.kHIDPage_AppleVendor,
        //     "PrimaryUsage": HIDEventBridge.kHIDUsage_AppleVendor_AmbientLightSensor
        // ]
        // HIDEventBridge.setMatching?(client, matching as CFDictionary)
        // HIDEventBridge.setDispatchQueue?(client, queue)
        // HIDEventBridge.activate?(client)
    }

    private func teardownEventClient() {
        if let client {
            HIDEventBridge.cancel?(client)
        }
        client = nil
    }

    private func readEvents() -> Reading {
        guard HIDEventBridge.isLoaded else {
            return Reading(
                ambientLightLux: nil, accelerometerX: nil, accelerometerY: nil, accelerometerZ: nil,
                gyroX: nil, gyroY: nil, gyroZ: nil,
                compassX: nil, compassY: nil, compassZ: nil,
                atmosphericPressure: nil, brightnessLevel: nil,
                frameworkLoaded: false, availableEventTypes: [], timestamp: Date()
            )
        }

        // Query which event creation functions are available
        var available: [String] = []
        if HIDEventBridge.createALSEvent != nil { available.append("AmbientLightSensor") }
        if HIDEventBridge.createAccelEvent != nil { available.append("Accelerometer") }
        if HIDEventBridge.createGyroEvent != nil { available.append("Gyro") }
        if HIDEventBridge.createCompassEvent != nil { available.append("Compass") }
        if HIDEventBridge.createPressureEvent != nil { available.append("AtmosphericPressure") }
        if HIDEventBridge.createBiometricEvent != nil { available.append("Biometric") }
        if HIDEventBridge.createForceEvent != nil { available.append("Force") }
        if HIDEventBridge.createProximityEvent != nil { available.append("Proximity") }
        if HIDEventBridge.createProximityLevelEvent != nil { available.append("ProximityLevel") }
        if HIDEventBridge.createHeartRateEvent != nil { available.append("HeartRate") }
        if HIDEventBridge.createBrightnessEvent != nil { available.append("Brightness") }
        if HIDEventBridge.createLEDEvent != nil { available.append("LED") }
        if HIDEventBridge.createProgressEvent != nil { available.append("Progress") }
        if HIDEventBridge.createDigitizerFingerEvent != nil { available.append("DigitizerFinger") }
        if HIDEventBridge.createDigitizerStylusEvent != nil { available.append("DigitizerStylus") }
        if HIDEventBridge.createGameControllerEvent != nil { available.append("GameController") }
        if HIDEventBridge.createGenericGestureEvent != nil { available.append("GenericGesture") }
        if HIDEventBridge.createSwipeEvent != nil { available.append("Swipe") }
        if HIDEventBridge.createDockSwipeEvent != nil { available.append("DockSwipe") }
        if HIDEventBridge.createNavigationSwipeEvent != nil { available.append("NavigationSwipe") }
        if HIDEventBridge.createFluidTouchGestureEvent != nil { available.append("FluidTouchGesture") }
        if HIDEventBridge.createBoundaryScrollEvent != nil { available.append("BoundaryScroll") }
        if HIDEventBridge.createSymbolicHotKeyEvent != nil { available.append("SymbolicHotKey") }
        if HIDEventBridge.createOrientationEvent != nil { available.append("Orientation") }
        if HIDEventBridge.createPolarOrientationEvent != nil { available.append("PolarOrientation") }
        if HIDEventBridge.createQuaternionOrientationEvent != nil { available.append("QuaternionOrientation") }
        if HIDEventBridge.createDeviceOrientationEvent != nil { available.append("DeviceOrientation") }
        if HIDEventBridge.createMotionActivityEvent != nil { available.append("MotionActivity") }
        if HIDEventBridge.createMotionGestureEvent != nil { available.append("MotionGesture") }
        if HIDEventBridge.createRotationEvent != nil { available.append("Rotation") }
        if HIDEventBridge.createTranslationEvent != nil { available.append("Translation") }
        if HIDEventBridge.createScaleEvent != nil { available.append("Scale") }
        if HIDEventBridge.createScrollEvent != nil { available.append("Scroll") }
        if HIDEventBridge.createKeyboardEvent != nil { available.append("Keyboard") }
        if HIDEventBridge.createMouseEvent != nil { available.append("Mouse") }
        if HIDEventBridge.createButtonEvent != nil { available.append("Button") }
        if HIDEventBridge.createCollectionEvent != nil { available.append("Collection") }
        if HIDEventBridge.createUnicodeEvent != nil { available.append("Unicode") }
        if HIDEventBridge.createTouchSensitiveButtonEvent != nil { available.append("TouchSensitiveButton") }
        if HIDEventBridge.createForceStageEvent != nil { available.append("ForceStage") }

        // Try reading ALS value from services
        var alsLux: Double? = nil
        if let client, let services = HIDEventBridge.copyServices?(client) as? [Any] {
            for service in services {
                let svc = service as! UnsafeMutableRawPointer
                if let value = HIDEventBridge.serviceClientCopyProperty?(svc, "CurrentALS" as CFString) {
                    alsLux = (value as? NSNumber)?.doubleValue
                }
                if alsLux == nil, let value = HIDEventBridge.serviceClientCopyProperty?(svc, "AmbientLightLevel" as CFString) {
                    alsLux = (value as? NSNumber)?.doubleValue
                }
            }
        }

        return Reading(
            ambientLightLux: alsLux,
            accelerometerX: nil, accelerometerY: nil, accelerometerZ: nil,
            gyroX: nil, gyroY: nil, gyroZ: nil,
            compassX: nil, compassY: nil, compassZ: nil,
            atmosphericPressure: nil, brightnessLevel: nil,
            frameworkLoaded: true,
            availableEventTypes: available,
            timestamp: Date()
        )
    }
}
