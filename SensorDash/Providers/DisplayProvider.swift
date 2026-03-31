import Foundation
import CoreGraphics

actor DisplayProvider {
    struct DisplayReading: Sendable {
        let displayID: CGDirectDisplayID
        let isBuiltIn: Bool
        let brightness: Float
        let linearBrightness: Float
        let canChangeBrightness: Bool
    }

    struct Reading: Sendable {
        let displays: [DisplayReading]
        let frameworkLoaded: Bool
        let timestamp: Date
    }

    private var isRunning = false

    func start() -> AsyncStream<Reading> {
        isRunning = true
        return AsyncStream { continuation in
            Task { [weak self] in
                while let self, await self.isRunning {
                    let reading = Self.readDisplays()
                    continuation.yield(reading)
                    try? await Task.sleep(for: .seconds(2))
                }
                continuation.finish()
            }
        }
    }

    func stop() { isRunning = false }

    private static func readDisplays() -> Reading {
        guard DSBridge.isLoaded else {
            return Reading(displays: [], frameworkLoaded: false, timestamp: Date())
        }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(16, &displayIDs, &displayCount)

        var readings: [DisplayReading] = []
        for i in 0..<Int(displayCount) {
            let did = displayIDs[i]
            var brightness: Float = 0
            var linearBrightness: Float = 0

            // Only call the functions that are known safe (brightness getters)
            let getBrightnessResult = DSBridge.getBrightness?(did, &brightness) ?? -1
            let getLinearResult = DSBridge.getLinearBrightness?(did, &linearBrightness) ?? -1
            let canChange = getBrightnessResult == 0
            let isBuiltIn = CGDisplayIsBuiltin(did) != 0

            readings.append(DisplayReading(
                displayID: did,
                isBuiltIn: isBuiltIn,
                brightness: brightness,
                linearBrightness: linearBrightness,
                canChangeBrightness: canChange
            ))
            _ = getLinearResult // suppress unused warning
        }

        return Reading(displays: readings, frameworkLoaded: true, timestamp: Date())
    }
}
