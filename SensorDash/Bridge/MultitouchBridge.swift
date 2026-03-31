import Foundation

// MARK: - Multitouch types (must be top-level for @convention(c) compatibility)

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTReadout {
    var pos: MTPoint
    var vel: MTPoint
}

struct MTContact {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTReadout
    var size: Float
    var pressure: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absoluteVector: MTReadout
    var unknown1: Int32
    var unknown2: Int32
    var density: Float
}

typealias MTDeviceRef = UnsafeMutableRawPointer
typealias MTActuatorRef = UnsafeMutableRawPointer
// Use raw pointers for @convention(c) compatibility since MTContact contains nested Swift structs
typealias MTContactCallback = @convention(c) (
    UnsafeMutableRawPointer?,       // device
    UnsafeMutableRawPointer?,       // contacts array
    Int32,                          // contact count
    Double,                         // timestamp
    Int32                           // frame
) -> Void
typealias MTContactGetFloatFn = @convention(c) (UnsafeMutableRawPointer) -> Float
typealias MTContactGetBoolFn = @convention(c) (UnsafeMutableRawPointer) -> Bool
typealias MTContactGetPixelFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Float>, UnsafeMutablePointer<Float>) -> Void

/// Bridge for the private MultitouchSupport framework.
enum MTBridge {
    private static let handle = FrameworkLoader.load(
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    )

    static var isLoaded: Bool { handle != nil }

    // MARK: - Device APIs
    typealias MTDeviceCreateDefaultFn = @convention(c) () -> MTDeviceRef?
    typealias MTDeviceCreateListFn = @convention(c) () -> CFArray?
    typealias MTDeviceCreateFromDeviceIDFn = @convention(c) (UInt64) -> MTDeviceRef?
    typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, MTContactCallback) -> Int32
    typealias MTDeviceStopFn = @convention(c) (MTDeviceRef) -> Int32
    typealias MTDeviceDriverIsReadyFn = @convention(c) (MTDeviceRef) -> Bool
    typealias MTDeviceCopyDeviceUsagePairsFn = @convention(c) (MTDeviceRef) -> CFArray?
    typealias MTDeviceVoidFn = @convention(c) (MTDeviceRef) -> Void

    static let deviceCreateDefault: MTDeviceCreateDefaultFn? = sym("MTDeviceCreateDefault")
    static let deviceCreateList: MTDeviceCreateListFn? = sym("MTDeviceCreateList")
    static let deviceCreateFromDeviceID: MTDeviceCreateFromDeviceIDFn? = sym("MTDeviceCreateFromDeviceID")
    static let deviceCreateFromGUID: ((@convention(c) (UInt64) -> MTDeviceRef?))? = sym("MTDeviceCreateFromGUID")

    // Device lifecycle
    typealias MTDeviceOpenFn = @convention(c) (MTDeviceRef) -> Int32
    typealias MTDeviceCloseFn = @convention(c) (MTDeviceRef) -> Int32
    // MTDeviceStart takes (device, unused_runloop_or_zero) -> void
    typealias MTDeviceStartFn2 = @convention(c) (MTDeviceRef, Int32) -> Void
    typealias MTDeviceStopFn2 = @convention(c) (MTDeviceRef) -> Void

    static let deviceOpen: MTDeviceOpenFn? = sym("MTDeviceOpen")
    static let deviceClose: MTDeviceCloseFn? = sym("MTDeviceClose")
    static let deviceStartRunning: MTDeviceStartFn2? = sym("MTDeviceStart")
    static let deviceStopRunning: MTDeviceStopFn2? = sym("MTDeviceStop")

    // Registration-based API
    typealias MTRegisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTContactCallback) -> Void
    typealias MTUnregisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTContactCallback) -> Void

    static let registerContactFrameCallback: MTRegisterContactFrameCallbackFn? = sym("MTRegisterContactFrameCallback")
    static let unregisterContactFrameCallback: MTUnregisterContactFrameCallbackFn? = sym("MTUnregisterContactFrameCallback")

    // Recording
    typealias MTDeviceBeginRecordingToFileFn = @convention(c) (MTDeviceRef, UnsafePointer<CChar>) -> Int32
    typealias MTDeviceBeginRecordingToDataFn = @convention(c) (MTDeviceRef) -> Int32
    typealias MTDeviceEndRecordingFn = @convention(c) (MTDeviceRef) -> Int32

    static let deviceBeginRecordingToFile: MTDeviceBeginRecordingToFileFn? = sym("MTDeviceBeginRecordingToFile")
    static let deviceBeginRecordingToData: MTDeviceBeginRecordingToDataFn? = sym("MTDeviceBeginRecordingToData")
    static let deviceEndRecording: MTDeviceEndRecordingFn? = sym("MTDeviceEndRecording")

    static let deviceDriverIsReady: MTDeviceDriverIsReadyFn? = sym("MTDeviceDriverIsReady")
    static let deviceCopyDeviceUsagePairs: MTDeviceCopyDeviceUsagePairsFn? = sym("MTDeviceCopyDeviceUsagePairs")
    static let deviceForcePropertiesRecache: MTDeviceVoidFn? = sym("MTDeviceForcePropertiesRecache")

    // Input dispatch
    typealias MTDeviceDispatchEventFn = @convention(c) (MTDeviceRef, Int32, Int32) -> Void
    static let deviceDispatchRelativeMouseEvent: MTDeviceDispatchEventFn? = sym("MTDeviceDispatchRelativeMouseEvent")
    static let deviceDispatchScrollWheelEvent: MTDeviceDispatchEventFn? = sym("MTDeviceDispatchScrollWheelEvent")
    static let deviceDispatchButtonEvent: MTDeviceDispatchEventFn? = sym("MTDeviceDispatchButtonEvent")
    static let deviceDispatchKeyboardEvent: MTDeviceDispatchEventFn? = sym("MTDeviceDispatchKeyboardEvent")
    static let deviceDispatchMomentumScrollEvent: MTDeviceDispatchEventFn? = sym("MTDeviceDispatchMomentumScrollEvent")

    // MARK: - Per-finger Contact APIs
    static let contactGetCentroidPixel: MTContactGetPixelFn? = sym("MTContact_getCentroidPixel")
    static let contactGetEllipseEccentricity: MTContactGetFloatFn? = sym("MTContact_getEllipseEccentricity")
    static let contactGetEllipseOrientationDegrees: MTContactGetFloatFn? = sym("MTContact_getEllipseOrientationDegrees")
    static let contactGetEllipseMeanRadius: MTContactGetFloatFn? = sym("MTContact_getEllipseMeanRadius")
    static let contactGetEllipseMajorAxisRadius: MTContactGetFloatFn? = sym("MTContact_getEllipseMajorAxisRadius")
    static let contactGetEllipseMinorAxisRadius: MTContactGetFloatFn? = sym("MTContact_getEllipseMinorAxisRadius")
    static let contactIsActive: MTContactGetBoolFn? = sym("MTContact_isActive")

    // MARK: - Haptic Actuator APIs
    typealias MTActuatorCreateFn = @convention(c) (UInt64) -> MTActuatorRef?
    typealias MTActuatorOpenFn = @convention(c) (MTActuatorRef) -> Int32
    typealias MTActuatorCloseFn = @convention(c) (MTActuatorRef) -> Int32
    typealias MTActuatorIsOpenFn = @convention(c) (MTActuatorRef) -> Bool
    typealias MTActuatorActuateFn = @convention(c) (MTActuatorRef, Int32, UnsafeMutableRawPointer?, Int32) -> Int32
    typealias MTActuatorGetBoolFn = @convention(c) (MTActuatorRef) -> Bool
    typealias MTActuatorSetBoolFn = @convention(c) (MTActuatorRef, Bool) -> Int32
    typealias MTActuatorGetDeviceIDFn = @convention(c) (MTActuatorRef) -> UInt64

    static let actuatorCreateFromDeviceID: MTActuatorCreateFn? = sym("MTActuatorCreateFromDeviceID")
    static let actuatorOpen: MTActuatorOpenFn? = sym("MTActuatorOpen")
    static let actuatorClose: MTActuatorCloseFn? = sym("MTActuatorClose")
    static let actuatorIsOpen: MTActuatorIsOpenFn? = sym("MTActuatorIsOpen")
    static let actuatorActuate: MTActuatorActuateFn? = sym("MTActuatorActuate")
    static let actuatorGetSystemActuationsEnabled: MTActuatorGetBoolFn? = sym("MTActuatorGetSystemActuationsEnabled")
    static let actuatorSetSystemActuationsEnabled: MTActuatorSetBoolFn? = sym("MTActuatorSetSystemActuationsEnabled")
    static let actuatorGetDeviceID: MTActuatorGetDeviceIDFn? = sym("MTActuatorGetDeviceID")
    static let actuatorSetFirmwareClicks: ((@convention(c) (MTActuatorRef, Bool) -> Int32))? = sym("MTActuatorSetFirmwareClicks")
    static let actuatorLoadActuations: ((@convention(c) (MTActuatorRef) -> Int32))? = sym("MTActuatorLoadActuations")

    // MARK: - Actuation
    typealias MTActuationActuateFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
    typealias MTActuationCreateFn = @convention(c) (CFDictionary) -> UnsafeMutableRawPointer?

    static let actuationActuate: MTActuationActuateFn? = sym("MTActuationActuate")
    static let actuationCreateFromDictionary: MTActuationCreateFn? = sym("MTActuationCreateFromDictionary")

    // MARK: - Misc
    static let absoluteTimeGetCurrent: ((@convention(c) () -> UInt64))? = sym("MTAbsoluteTimeGetCurrent")

    private static func sym<T>(_ name: String) -> T? {
        guard let h = handle else { return nil }
        return FrameworkLoader.symbol(h, name)
    }
}
