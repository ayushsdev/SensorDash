import Foundation

/// Bridge for the private AppleDepth framework — LiDAR and binocular depth APIs.
enum DepthBridge {
    private static let handle = FrameworkLoader.load(
        "/System/Library/PrivateFrameworks/AppleDepth.framework/AppleDepth"
    )

    static var isLoaded: Bool { handle != nil }

    static let classNames = [
        "ADBinocularDepthExecutor",
        "ADBinocularDepthExecutorParameters",
        "ADBinocularDepthPipeline",
        "ADBinocularDepthPipelineParameters",
        "ADBinocularDepthOutput",
        "ADBinocularDepthWarperMesh",
        "ADBinocularDepthFlow",
        "ADDensifiedLiDARFocusAssistExecutor",
        "ADDensifiedLiDARFocusAssistExecutorParameters",
        "ADDensifiedLiDARFocusAssistFlow",
        "ADAdaptiveCorrectionPipeline",
        "ADAdaptiveCorrectionPipelineParameters",
        "ADAdaptiveCorrectionDualCameraCalibrationModel",
        "ADAnchoredVector",
        "ADConfidenceLevelRanges",
    ]

    static func availableClasses() -> [String: Bool] {
        _ = handle
        var result: [String: Bool] = [:]
        for name in classNames {
            result[name] = NSClassFromString(name) != nil
        }
        return result
    }
}
