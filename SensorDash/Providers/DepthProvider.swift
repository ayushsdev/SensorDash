import Foundation

actor DepthProvider {
    struct Reading: Sendable {
        let available: Bool
        let frameworkLoaded: Bool
        let availableClasses: [String: Bool]
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
                    try? await Task.sleep(for: .seconds(10))
                }
                continuation.finish()
            }
        }
    }

    func stop() { isRunning = false }

    private static func read() -> Reading {
        let classes = DepthBridge.availableClasses()
        let available = classes.values.contains(true)
        return Reading(
            available: available,
            frameworkLoaded: DepthBridge.isLoaded,
            availableClasses: classes,
            timestamp: Date()
        )
    }
}
