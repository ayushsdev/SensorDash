import Foundation

/// Bridge for undocumented CoreMotion classes.
/// Public classes (CMMotionManager, CMAltimeter, CMHeadphoneMotionManager) are used directly.
/// This bridge discovers and probes private classes via the ObjC runtime.
enum CoreMotionBridge {
    private static let handle = FrameworkLoader.load(
        "/System/Library/Frameworks/CoreMotion.framework/CoreMotion"
    )

    /// All known undocumented CoreMotion classes.
    static let privateClassNames = [
        "CMAbsoluteAltitudeData",
        "CMAmbientPressureData",
        "CMAmbientPressureDataArray",
        "CMRecordedPressureData",
        "CMCalorieData",
        "CMCalorieUserInfo",
        "CMCalorieUtils",
        "CMHeartRateData",
        "CMHighFrequencyHeartRateData",
        "CMHeadphoneActivityManager",
        "CM2DSkeletonTransform",
        "CM3DLiftedSkeletonTransform",
        "CM3DRetargetedSkeletonTransform",
        "CMSkeletonCollection",
        "CMBatchedSensorManager",
        "CMAudioAccessoryManager",
        "CMAudioAccessoryUsageManager",
        "CMActivity",
        "CMActivityManager",
        "CMActivityAlarm",
        "CMActivityEventData",
        "CMPedometerBin",
        "CMALSPhone",
        "CMAnomalyMessenger",
        "CLSensorRecorderRecordSensorTypeFor",
        "CLSensorRecorderSensorAvailable",
        "CLSensorRecorderSensorDataRequestById",
        "CLSensorRecorderSensorMeta",
        "CLSensorRecorderSensorMetaRequestByDateRange",
        "CLSensorRecorderSensorMetaRequestById",
        "CLSensorRecorderSensorSampleRate",
        "CLSensorRecorderWriteSensorDataToFileForDateRange",
        "CLDeviceMotionProperties",
    ]

    static func availableClasses() -> [String: Bool] {
        _ = handle
        var result: [String: Bool] = [:]
        for name in privateClassNames {
            result[name] = NSClassFromString(name) != nil
        }
        return result
    }

    /// Try to get batched sensor manager info.
    static func batchedSensorManagerInfo() -> [String: Any]? {
        _ = handle
        guard let cls = NSClassFromString("CMBatchedSensorManager") as? NSObject.Type else { return nil }
        let sel = NSSelectorFromString("isSupported")
        if cls.responds(to: sel) {
            let supported = cls.perform(sel)
            return ["isSupported": supported != nil]
        }
        return nil
    }
}
