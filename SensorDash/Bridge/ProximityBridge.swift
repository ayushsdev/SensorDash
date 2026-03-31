import Foundation

/// Bridge for the private Proximity framework — UWB chip, Bluetooth RSSI, beacon ranging.
enum ProximityBridge {
    private static let handle = FrameworkLoader.load(
        "/System/Library/PrivateFrameworks/Proximity.framework/Proximity"
    )

    static var isLoaded: Bool { handle != nil }

    /// All discoverable private ObjC classes in the Proximity framework.
    static let classNames = [
        "PRChipInfo",
        "PRBTRSSI",
        "PRBTRangingSession",
        "PRBTRangingClientExportedObject",
        "PRBeacon",
        "PRBeaconDescriptor",
        "PRBeaconListener",
        "PRBeaconRangingSession",
        "PRCompanionRangingSession",
        "PRGenericRangingSession",
        "PRContactAllowlist",
        "PRDeviceScore",
        "PRAngleMeasurement",
        "PRGetPowerStatsResponse",
        "PRHelloResponse",
    ]

    /// Check which classes are available at runtime.
    static func availableClasses() -> [String: Bool] {
        // Ensure framework is loaded
        _ = handle
        var result: [String: Bool] = [:]
        for name in classNames {
            result[name] = NSClassFromString(name) != nil
        }
        return result
    }

    /// Try to get UWB chip info via PRChipInfo.
    static func chipInfo() -> [String: Any]? {
        _ = handle
        guard let cls = NSClassFromString("PRChipInfo") as? NSObject.Type else { return nil }
        // Try common factory methods
        for selector in ["chipInfo", "currentChipInfo", "sharedChipInfo", "new"] {
            let sel = NSSelectorFromString(selector)
            if cls.responds(to: sel) {
                if let obj = cls.perform(sel)?.takeUnretainedValue() as? NSObject {
                    return extractProperties(from: obj)
                }
            }
        }
        return nil
    }

    /// Extract readable properties from a private NSObject using KVC.
    private static func extractProperties(from obj: NSObject) -> [String: Any] {
        var dict: [String: Any] = [:]
        let mirror = Mirror(reflecting: obj)
        for child in mirror.children {
            if let label = child.label {
                dict[label] = child.value
            }
        }
        // Also try description
        dict["description"] = obj.description
        return dict
    }
}
