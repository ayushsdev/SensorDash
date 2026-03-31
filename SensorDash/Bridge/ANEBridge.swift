import Foundation

/// Bridge for the private AppleNeuralEngine framework.
enum ANEBridge {
    private static let handle = FrameworkLoader.load(
        "/System/Library/PrivateFrameworks/AppleNeuralEngine.framework/AppleNeuralEngine"
    )

    static var isLoaded: Bool { handle != nil }

    /// All known private ObjC classes in AppleNeuralEngine.
    static let classNames = [
        "_ANEClient",
        "_ANEDaemonConnection",
        "_ANEDeviceController",
        "_ANEDeviceInfo",
        "_ANEModel",
        "_ANEModelInstanceParameters",
        "_ANEModelToken",
        "_ANEBuffer",
        "_ANEIOSurfaceObject",
        "_ANEIOSurfaceOutputSets",
        "_ANEInMemoryModel",
        "_ANEInMemoryModelDescriptor",
        "_ANEInputBuffersReady",
        "_ANEOutputSetEnqueue",
        "_ANEChainingRequest",
        "_ANECloneHelper",
        "_ANELog",
        "_ANEErrors",
        "_ANEHashEncoding",
        "_ANEDataReporter",
    ]

    static func availableClasses() -> [String: Bool] {
        _ = handle
        var result: [String: Bool] = [:]
        for name in classNames {
            result[name] = NSClassFromString(name) != nil
        }
        return result
    }

    /// Try to get device info from _ANEDeviceInfo.
    static func deviceInfo() -> [String: Any]? {
        _ = handle
        guard let cls = NSClassFromString("_ANEDeviceInfo") as? NSObject.Type else { return nil }
        for selector in ["new", "deviceInfo", "sharedDeviceInfo", "currentDeviceInfo"] {
            let sel = NSSelectorFromString(selector)
            if cls.responds(to: sel) {
                if let obj = cls.perform(sel)?.takeUnretainedValue() as? NSObject {
                    var dict: [String: Any] = ["class": "_ANEDeviceInfo", "description": obj.description]
                    let mirror = Mirror(reflecting: obj)
                    for child in mirror.children {
                        if let label = child.label {
                            dict[label] = "\(child.value)"
                        }
                    }
                    return dict
                }
            }
        }
        return nil
    }

    /// Try to connect via _ANEClient.
    static func clientInfo() -> [String: Any]? {
        _ = handle
        guard let cls = NSClassFromString("_ANEClient") as? NSObject.Type else { return nil }
        for selector in ["new", "sharedClient", "localClient"] {
            let sel = NSSelectorFromString(selector)
            if cls.responds(to: sel) {
                if let obj = cls.perform(sel)?.takeUnretainedValue() as? NSObject {
                    return ["class": "_ANEClient", "description": obj.description]
                }
            }
        }
        return nil
    }
}
