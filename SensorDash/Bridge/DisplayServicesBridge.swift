import Foundation
import CoreGraphics

/// Bridge for the private DisplayServices framework.
/// All functions loaded via dlopen/dlsym at runtime.
enum DSBridge {
    private static let handle = FrameworkLoader.load(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
    )

    static var isLoaded: Bool { handle != nil }

    // Most DisplayServices functions follow the pattern:
    //   Int32 FunctionName(CGDirectDisplayID display, ...) -> returns 0 on success
    // Bool-like queries return Int32 where nonzero = true

    // MARK: - Common typedefs
    typealias DisplayFloat = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias DisplaySetFloat = @convention(c) (CGDirectDisplayID, Float) -> Int32
    typealias DisplayBool = @convention(c) (CGDirectDisplayID) -> Int32  // returns nonzero = true
    typealias DisplayGetBool = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Int32
    typealias DisplayInt32 = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Int32>) -> Int32
    typealias DisplaySetInt32 = @convention(c) (CGDirectDisplayID, Int32) -> Int32
    typealias DisplayVoid = @convention(c) (CGDirectDisplayID) -> Int32

    // MARK: - Brightness
    static let getBrightness: DisplayFloat? = sym("DisplayServicesGetBrightness")
    static let setBrightness: DisplaySetFloat? = sym("DisplayServicesSetBrightness")
    static let setBrightnessSmooth: DisplaySetFloat? = sym("DisplayServicesSetBrightnessSmooth")
    static let setBrightnessWithType: DisplaySetFloat? = sym("DisplayServicesSetBrightnessWithType")
    static let getBrightnessIncrement: DisplayFloat? = sym("DisplayServicesGetBrightnessIncrement")
    static let canChangeBrightness: DisplayBool? = sym("DisplayServicesCanChangeBrightness")
    static let needsBrightnessSmoothing: DisplayBool? = sym("DisplayServicesNeedsBrightnessSmoothing")
    static let createBrightnessTable: ((@convention(c) (CGDirectDisplayID) -> CFArray?))? = sym("DisplayServicesCreateBrightnessTable")

    // MARK: - Linear Brightness
    static let getLinearBrightness: DisplayFloat? = sym("DisplayServicesGetLinearBrightness")
    static let setLinearBrightness: DisplaySetFloat? = sym("DisplayServicesSetLinearBrightness")
    typealias GetLinearRangeFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>, UnsafeMutablePointer<Float>) -> Int32
    static let getLinearBrightnessUsableRange: GetLinearRangeFn? = sym("DisplayServicesGetLinearBrightnessUsableRange")

    // MARK: - Ambient Light Compensation
    static let hasALC: DisplayBool? = sym("DisplayServicesHasAmbientLightCompensation")
    static let alcEnabled: DisplayBool? = sym("DisplayServicesAmbientLightCompensationEnabled")
    static let enableALC: DisplaySetInt32? = sym("DisplayServicesEnableAmbientLightCompensation")
    static let canResetAmbientLight: DisplayBool? = sym("DisplayServicesCanResetAmbientLight")

    // MARK: - Reset
    static let resetAmbientLight: DisplayVoid? = sym("DisplayServicesResetAmbientLight")
    static let resetAmbientLightAll: ((@convention(c) () -> Int32))? = sym("DisplayServicesResetAmbientLightAll")

    // MARK: - Display queries (all return Int32, nonzero = true)
    static let isBuiltInDisplay: DisplayBool? = sym("DisplayServicesIsBuiltInDisplay")
    static let isSmartDisplay: DisplayBool? = sym("DisplayServicesIsSmartDisplay")
    static let hasPowerMode: DisplayBool? = sym("DisplayServicesHasPowerMode")
    static let hasPowerButton: DisplayBool? = sym("DisplayServicesHasPowerButton")
    static let hasBrightnessButtons: DisplayBool? = sym("DisplayServicesHasBrightnessButtons")
    static let hasCommit: DisplayBool? = sym("DisplayServicesHasCommit")
    static let hasTouchSwitchDisable: DisplayBool? = sym("DisplayServicesHasTouchSwitchDisable")
    static let hasOptionsAuthorization: DisplayBool? = sym("DisplayServicesHasOptionsAuthorization")
    static let bezelButtonsLocked: DisplayBool? = sym("DisplayServicesBezelButtonsLocked")

    // MARK: - Power & Buttons
    static let getPowerMode: DisplayInt32? = sym("DisplayServicesGetPowerMode")
    static let setPowerMode: DisplaySetInt32? = sym("DisplayServicesSetPowerMode")
    static let getPowerButtonEnabled: DisplayGetBool? = sym("DisplayServicesGetPowerButtonEnabled")
    static let setPowerButtonEnabled: DisplaySetInt32? = sym("DisplayServicesSetPowerButtonEnabled")
    static let getBrightnessButtonsEnabled: DisplayGetBool? = sym("DisplayServicesGetBrightnessButtonsEnabled")
    static let setBrightnessButtonsEnabled: DisplaySetInt32? = sym("DisplayServicesSetBrightnessButtonsEnabled")

    // MARK: - Dynamic Slider & Commit
    static let getDynamicSlider: DisplayFloat? = sym("DisplayServicesGetDynamicSlider")
    static let setDynamicSlider: DisplaySetFloat? = sym("DisplayServicesSetDynamicSlider")
    static let getCommitInterval: DisplayInt32? = sym("DisplayServicesGetCommitInterval")
    static let commitSettings: DisplayVoid? = sym("DisplayServicesCommitSettings")
    static let setToDefaults: DisplayVoid? = sym("DisplayServicesSetToDefaults")

    // MARK: - Authorization
    static let getAuthorized: DisplayGetBool? = sym("DisplayServicesGetAuthorized")
    static let setAuthorized: DisplaySetInt32? = sym("DisplayServicesSetAuthorized")

    // MARK: - Screen Color Temperature (IOKit)
    private static let iokitHandle = FrameworkLoader.load("/System/Library/Frameworks/IOKit.framework/IOKit")
    typealias SetScreenTempFn = @convention(c) (UInt32, Float) -> Int32
    static let setScreenVirtualTemperature: SetScreenTempFn? = {
        guard let h = iokitHandle else { return nil }
        return FrameworkLoader.symbol(h, "IOAVVideoInterfaceSetScreenVirtualTemperature")
    }()

    // MARK: - Helpers
    private static func sym<T>(_ name: String) -> T? {
        guard let h = handle else { return nil }
        return FrameworkLoader.symbol(h, name)
    }

    /// Safe bool query — calls the function and interprets nonzero as true.
    static func queryBool(_ fn: DisplayBool?, display: CGDirectDisplayID) -> Bool {
        guard let fn else { return false }
        return fn(display) != 0
    }
}
