import Foundation

/// Bridge for IOHIDEvent system — semi-private APIs in IOKit for reading hardware sensor events.
/// Covers ambient light, accelerometer, gyroscope, barometer, proximity, and all 30+ event types.
enum HIDEventBridge {
    private static let handle = FrameworkLoader.load("/System/Library/Frameworks/IOKit.framework/IOKit")

    static var isLoaded: Bool { handle != nil }

    // MARK: - Opaque types
    typealias IOHIDEventSystemClientRef = UnsafeMutableRawPointer
    typealias IOHIDEventRef = UnsafeMutableRawPointer
    typealias IOHIDServiceClientRef = UnsafeMutableRawPointer

    // MARK: - Event System Client
    typealias CreateClientFn = @convention(c) (CFAllocator?) -> IOHIDEventSystemClientRef?
    typealias SetMatchingFn = @convention(c) (IOHIDEventSystemClientRef, CFDictionary) -> Void
    typealias SetDispatchQueueFn = @convention(c) (IOHIDEventSystemClientRef, DispatchQueue) -> Void
    typealias ActivateFn = @convention(c) (IOHIDEventSystemClientRef) -> Void
    typealias CancelFn = @convention(c) (IOHIDEventSystemClientRef) -> Void
    typealias CopyServicesFn = @convention(c) (IOHIDEventSystemClientRef) -> CFArray?

    static let createClient: CreateClientFn? = sym("IOHIDEventSystemClientCreate")
    static let setMatching: SetMatchingFn? = sym("IOHIDEventSystemClientSetMatching")
    static let setDispatchQueue: SetDispatchQueueFn? = sym("IOHIDEventSystemClientSetDispatchQueue")
    static let activate: ActivateFn? = sym("IOHIDEventSystemClientActivate")
    static let cancel: CancelFn? = sym("IOHIDEventSystemClientCancel")
    static let copyServices: CopyServicesFn? = sym("IOHIDEventSystemClientCopyServices")

    // MARK: - Event Callback Registration
    typealias EventCallbackFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, IOHIDEventRef) -> Void
    typealias RegisterEventCallbackFn = @convention(c) (IOHIDEventSystemClientRef, EventCallbackFn?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void

    static let registerEventCallback: RegisterEventCallbackFn? = sym("IOHIDEventSystemClientRegisterEventCallback")

    // MARK: - Service Client
    typealias ServiceClientCopyPropertyFn = @convention(c) (IOHIDServiceClientRef, CFString) -> CFTypeRef?

    static let serviceClientCopyProperty: ServiceClientCopyPropertyFn? = sym("IOHIDServiceClientCopyProperty")

    // MARK: - Event Reading
    typealias EventGetTypeFn = @convention(c) (IOHIDEventRef) -> Int32
    typealias EventGetFloatValueFn = @convention(c) (IOHIDEventRef, Int32) -> Double
    typealias EventGetIntValueFn = @convention(c) (IOHIDEventRef, Int32) -> Int64
    typealias EventConformsToFn = @convention(c) (IOHIDEventRef, Int32) -> Bool
    typealias EventCopyDescriptionFn = @convention(c) (IOHIDEventRef) -> CFString?

    static let eventGetType: EventGetTypeFn? = sym("IOHIDEventGetType")
    static let eventGetFloatValue: EventGetFloatValueFn? = sym("IOHIDEventGetFloatValue")
    static let eventGetIntegerValue: EventGetIntValueFn? = sym("IOHIDEventGetIntegerValue")
    static let eventConformsTo: EventConformsToFn? = sym("IOHIDEventConformsTo")
    static let eventCopyDescription: EventCopyDescriptionFn? = sym("IOHIDEventCopyDescription")

    // MARK: - Event Type Constants (from IOHIDEventTypes.h, private)
    static let kIOHIDEventTypeNULL: Int32 = 0
    static let kIOHIDEventTypeVendorDefined: Int32 = 1
    static let kIOHIDEventTypeButton: Int32 = 2
    static let kIOHIDEventTypeKeyboard: Int32 = 3
    static let kIOHIDEventTypeTranslation: Int32 = 4
    static let kIOHIDEventTypeRotation: Int32 = 5
    static let kIOHIDEventTypeScroll: Int32 = 6
    static let kIOHIDEventTypeScale: Int32 = 7
    static let kIOHIDEventTypeZoom: Int32 = 8
    static let kIOHIDEventTypeVelocity: Int32 = 9
    static let kIOHIDEventTypeOrientation: Int32 = 10
    static let kIOHIDEventTypeDigitizer: Int32 = 11
    static let kIOHIDEventTypeAmbientLightSensor: Int32 = 12
    static let kIOHIDEventTypeAccelerometer: Int32 = 13
    static let kIOHIDEventTypeProximity: Int32 = 14
    static let kIOHIDEventTypeTemperature: Int32 = 15
    static let kIOHIDEventTypeNavigationSwipe: Int32 = 16
    static let kIOHIDEventTypePointer: Int32 = 17
    static let kIOHIDEventTypeProgress: Int32 = 18
    static let kIOHIDEventTypeMultiAxisPointer: Int32 = 19
    static let kIOHIDEventTypeGyro: Int32 = 20
    static let kIOHIDEventTypeCompass: Int32 = 21
    static let kIOHIDEventTypeDockSwipe: Int32 = 22
    static let kIOHIDEventTypeSymbolicHotKey: Int32 = 23
    static let kIOHIDEventTypePower: Int32 = 24
    static let kIOHIDEventTypeLED: Int32 = 25
    static let kIOHIDEventTypeFluidTouchGesture: Int32 = 26
    static let kIOHIDEventTypeBoundaryScroll: Int32 = 27
    static let kIOHIDEventTypeBiometric: Int32 = 28
    static let kIOHIDEventTypeUnicode: Int32 = 29
    static let kIOHIDEventTypeAtmosphericPressure: Int32 = 30
    static let kIOHIDEventTypeForce: Int32 = 31
    static let kIOHIDEventTypeMotionActivity: Int32 = 32
    static let kIOHIDEventTypeMotionGesture: Int32 = 33
    static let kIOHIDEventTypeGameController: Int32 = 34
    static let kIOHIDEventTypeHumidity: Int32 = 35
    static let kIOHIDEventTypeBrightness: Int32 = 36
    static let kIOHIDEventTypeGenericGesture: Int32 = 37
    static let kIOHIDEventTypeHeartRate: Int32 = 38

    // MARK: - Event Field Constants
    static let kIOHIDEventFieldAmbientLightSensorLevel: Int32 = (12 << 16) | 0
    static let kIOHIDEventFieldAccelerometerX: Int32 = (13 << 16) | 0
    static let kIOHIDEventFieldAccelerometerY: Int32 = (13 << 16) | 1
    static let kIOHIDEventFieldAccelerometerZ: Int32 = (13 << 16) | 2
    static let kIOHIDEventFieldGyroX: Int32 = (20 << 16) | 0
    static let kIOHIDEventFieldGyroY: Int32 = (20 << 16) | 1
    static let kIOHIDEventFieldGyroZ: Int32 = (20 << 16) | 2
    static let kIOHIDEventFieldCompassX: Int32 = (21 << 16) | 0
    static let kIOHIDEventFieldCompassY: Int32 = (21 << 16) | 1
    static let kIOHIDEventFieldCompassZ: Int32 = (21 << 16) | 2
    static let kIOHIDEventFieldAtmosphericPressureLevel: Int32 = (30 << 16) | 0
    static let kIOHIDEventFieldBrightnessLevel: Int32 = (36 << 16) | 0

    // MARK: - HID Page/Usage for matching
    static let kHIDPage_AppleVendor: Int = 0xff00
    static let kHIDUsage_AppleVendor_AmbientLightSensor: Int = 0x0005

    // MARK: - Event Creation Functions (for reference/completeness)
    typealias CreateALSEventFn = @convention(c) (CFAllocator?, UInt64, Float, UInt32) -> IOHIDEventRef?
    typealias CreateAccelEventFn = @convention(c) (CFAllocator?, UInt64, Float, Float, Float, UInt32) -> IOHIDEventRef?
    typealias CreateGyroEventFn = @convention(c) (CFAllocator?, UInt64, Float, Float, Float, UInt32) -> IOHIDEventRef?
    typealias CreatePressureEventFn = @convention(c) (CFAllocator?, UInt64, Float, UInt32) -> IOHIDEventRef?
    typealias CreateBiometricEventFn = @convention(c) (CFAllocator?, UInt64, Float, UInt32) -> IOHIDEventRef?
    typealias CreateForceEventFn = @convention(c) (CFAllocator?, UInt64, Float, UInt32, UInt32) -> IOHIDEventRef?
    typealias CreateProximityEventFn = @convention(c) (CFAllocator?, UInt64, UInt32, UInt32) -> IOHIDEventRef?
    typealias CreateHeartRateEventFn = @convention(c) (CFAllocator?, UInt64, Float, UInt32) -> IOHIDEventRef?

    static let createALSEvent: CreateALSEventFn? = sym("IOHIDEventCreateAmbientLightSensorEvent")
    static let createAccelEvent: CreateAccelEventFn? = sym("IOHIDEventCreateAccelerometerEvent")
    static let createAccelEventWithType: CreateAccelEventFn? = sym("IOHIDEventCreateAccelerometerEventWithType")
    static let createGyroEvent: CreateGyroEventFn? = sym("IOHIDEventCreateGyroEvent")
    static let createGyroEventWithType: CreateGyroEventFn? = sym("IOHIDEventCreateGyroEventWithType")
    static let createCompassEvent: CreateAccelEventFn? = sym("IOHIDEventCreateCompassEvent")
    static let createCompassEventWithType: CreateAccelEventFn? = sym("IOHIDEventCreateCompassEventWithType")
    static let createPressureEvent: CreatePressureEventFn? = sym("IOHIDEventCreateAtmosphericPressureEvent")
    static let createBiometricEvent: CreateBiometricEventFn? = sym("IOHIDEventCreateBiometricEvent")
    static let createForceEvent: CreateForceEventFn? = sym("IOHIDEventCreateForceEvent")
    static let createProximityEvent: CreateProximityEventFn? = sym("IOHIDEventCreateProximtyEvent")
    static let createProximityLevelEvent: CreatePressureEventFn? = sym("IOHIDEventCreateProximtyLevelEvent")
    static let createHeartRateEvent: CreateHeartRateEventFn? = sym("IOHIDEventCreateHeartRateEvent")
    static let createBrightnessEvent: CreatePressureEventFn? = sym("IOHIDEventCreateBrightnessEvent")
    static let createLEDEvent: CreatePressureEventFn? = sym("IOHIDEventCreateLEDEvent")
    static let createProgressEvent: CreatePressureEventFn? = sym("IOHIDEventCreateProgressEvent")

    // Digitizer/stylus
    static let createDigitizerFingerEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateDigitizerFingerEvent")
    static let createDigitizerStylusEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateDigitizerStylusEvent")
    static let createDigitizerStylusEventWithPolarOrientation: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateDigitizerStylusEventWithPolarOrientation")

    // Gesture/swipe/controller
    static let createGameControllerEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateGameControllerEvent")
    static let createGenericGestureEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateGenericGestureEvent")
    static let createSwipeEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateSwipeEvent")
    static let createDockSwipeEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateDockSwipeEvent")
    static let createNavigationSwipeEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateNavigationSwipeEvent")
    static let createFluidTouchGestureEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateFluidTouchGestureEvent")
    static let createBoundaryScrollEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateBoundaryScrollEvent")
    static let createSymbolicHotKeyEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateSymbolicHotKeyEvent")

    // Orientation/motion
    static let createOrientationEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateOrientationEvent")
    static let createPolarOrientationEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreatePolarOrientationEvent")
    static let createQuaternionOrientationEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateQuaternionOrientationEvent")
    static let createDeviceOrientationEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateDeviceOrientationEventWithUsage")
    static let createMotionActivityEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateMotionActivtyEvent")
    static let createMotionGestureEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateMotionGestureEvent")

    // Misc
    static let createRotationEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateRotationEvent")
    static let createTranslationEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateTranslationEvent")
    static let createScaleEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateScaleEvent")
    static let createScrollEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateScrollEvent")
    static let createKeyboardEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateKeyboardEvent")
    static let createMouseEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateMouseEvent")
    static let createRelativePointerEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateRelativePointerEvent")
    static let createButtonEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateButtonEvent")
    static let createCollectionEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateCollectionEvent")
    static let createUnicodeEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateUnicodeEvent")
    static let createTouchSensitiveButtonEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateTouchSensitiveButtonEvent")
    static let createForceStageEvent: UnsafeMutableRawPointer? = rawSym("IOHIDEventCreateForceStageEvent")

    // Utility
    typealias EventAppendFn = @convention(c) (IOHIDEventRef, IOHIDEventRef) -> Void
    typealias EventCreateCopyFn = @convention(c) (CFAllocator?, IOHIDEventRef) -> IOHIDEventRef?
    typealias EventCreateDataFn = @convention(c) (IOHIDEventRef) -> CFData?

    static let eventAppendEvent: EventAppendFn? = sym("IOHIDEventAppendEvent")
    static let eventCreateCopy: EventCreateCopyFn? = sym("IOHIDEventCreateCopy")
    static let eventCreateData: EventCreateDataFn? = sym("IOHIDEventCreateData")

    // MARK: - Helpers
    private static func sym<T>(_ name: String) -> T? {
        guard let h = handle else { return nil }
        return FrameworkLoader.symbol(h, name)
    }

    private static func rawSym(_ name: String) -> UnsafeMutableRawPointer? {
        guard let h = handle else { return nil }
        return dlsym(h, name)
    }
}
