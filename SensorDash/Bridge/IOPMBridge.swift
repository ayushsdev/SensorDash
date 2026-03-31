import Foundation
import IOKit

/// Bridge for undocumented IOKit Power Management functions.
/// Public IOPM functions are available via the bridging header; this covers the private ones.
enum IOPMBridge {
    private static let handle = FrameworkLoader.load("/System/Library/Frameworks/IOKit.framework/IOKit")

    // MARK: - Battery & Thermal (Private)
    typealias CopyBatteryHeatMapFn = @convention(c) () -> CFDictionary?
    typealias CopyCPUPowerStatusFn = @convention(c) () -> CFDictionary?
    typealias GetThermalWarningLevelFn = @convention(c) (UnsafeMutablePointer<UInt32>) -> IOReturn
    typealias GetDarkWakeThermalEmergencyCountFn = @convention(c) (UnsafeMutablePointer<UInt32>) -> IOReturn
    typealias CopyPowerHistoryFn = @convention(c) () -> CFArray?
    typealias CopyPowerHistoryDetailedFn = @convention(c) () -> CFDictionary?
    typealias CopyPowerStateInfoFn = @convention(c) () -> CFDictionary?
    typealias SleepEnabledFn = @convention(c) () -> Bool
    typealias UserIsActiveFn = @convention(c) () -> Bool
    typealias CopyActivePMPreferencesFn = @convention(c) () -> CFDictionary?
    typealias CopyAssertionsByProcessFn = @convention(c) (UnsafeMutablePointer<CFDictionary?>) -> IOReturn
    typealias CopyAssertionsStatusFn = @convention(c) (UnsafeMutablePointer<CFDictionary?>) -> IOReturn
    typealias CopyAssertionActivityAggregateFn = @convention(c) () -> CFDictionary?
    typealias CopyAssertionActivityLogFn = @convention(c) () -> CFArray?

    static let copyBatteryHeatMap: CopyBatteryHeatMapFn? = sym("IOPMCopyBatteryHeatMap")
    static let copyCPUPowerStatus: CopyCPUPowerStatusFn? = sym("IOPMCopyCPUPowerStatus")
    static let getThermalWarningLevel: GetThermalWarningLevelFn? = sym("IOPMGetThermalWarningLevel")
    static let getDarkWakeThermalEmergencyCount: GetDarkWakeThermalEmergencyCountFn? = sym("IOPMGetDarkWakeThermalEmergencyCount")
    static let copyPowerHistory: CopyPowerHistoryFn? = sym("IOPMCopyPowerHistory")
    static let copyPowerHistoryDetailed: CopyPowerHistoryDetailedFn? = sym("IOPMCopyPowerHistoryDetailed")
    static let copyPowerStateInfo: CopyPowerStateInfoFn? = sym("IOPMCopyPowerStateInfo")
    static let sleepEnabled: SleepEnabledFn? = sym("IOPMSleepEnabled")
    static let userIsActive: UserIsActiveFn? = sym("IOPMUserIsActive")
    static let copyActivePMPreferences: CopyActivePMPreferencesFn? = sym("IOPMCopyActivePMPreferences")
    static let copyAssertionsByProcess: CopyAssertionsByProcessFn? = sym("IOPMCopyAssertionsByProcess")
    static let copyAssertionsStatus: CopyAssertionsStatusFn? = sym("IOPMCopyAssertionsStatus")
    static let copyAssertionActivityAggregate: CopyAssertionActivityAggregateFn? = sym("IOPMCopyAssertionActivityAggregate")
    static let copyAssertionActivityLog: CopyAssertionActivityLogFn? = sym("IOPMCopyAssertionActivityLog")

    // MARK: - SMC helpers
    typealias SMCKeyProxyPresentFn = @convention(c) () -> Bool
    typealias SupportsHPMFn = @convention(c) () -> Bool
    typealias SupportsSilentRunningFn = @convention(c) () -> Bool

    static let smcKeyProxyPresent: SMCKeyProxyPresentFn? = sym("IOSMCKeyProxyPresent")
    static let supportsHPM: SupportsHPMFn? = sym("smcSupportsHPM")
    static let supportsSilentRunning: SupportsSilentRunningFn? = sym("smcSupportsSilentRunning")

    private static func sym<T>(_ name: String) -> T? {
        guard let h = handle else { return nil }
        return FrameworkLoader.symbol(h, name)
    }
}
