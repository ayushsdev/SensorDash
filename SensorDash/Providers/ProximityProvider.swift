import Foundation

actor ProximityProvider {
    struct Reading: Sendable {
        let chipAvailable: Bool
        let frameworkLoaded: Bool
        let availableClasses: [String: Bool]
        let chipInfo: [String: String]
        let timestamp: Date
    }

    private var isRunning = false

    func start() -> AsyncStream<Reading> {
        isRunning = true
        return AsyncStream { continuation in
            Task { [weak self] in
                while let self, await self.isRunning {
                    let reading = Self.read()
                    continuation.yield(reading)
                    try? await Task.sleep(for: .seconds(5))
                }
                continuation.finish()
            }
        }
    }

    func stop() { isRunning = false }

    private static func read() -> Reading {
        let classes = ProximityBridge.availableClasses()
        let chipAvailable = classes["PRChipInfo"] == true

        var chipInfo: [String: String] = [:]
        if let info = ProximityBridge.chipInfo() {
            for (k, v) in info {
                chipInfo[k] = "\(v)"
            }
        }

        return Reading(
            chipAvailable: chipAvailable,
            frameworkLoaded: ProximityBridge.isLoaded,
            availableClasses: classes,
            chipInfo: chipInfo,
            timestamp: Date()
        )
    }
}
