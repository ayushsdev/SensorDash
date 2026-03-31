import Foundation

actor ANEProvider {
    struct Reading: Sendable {
        let available: Bool
        let frameworkLoaded: Bool
        let availableClasses: [String: Bool]
        let deviceInfo: [String: String]
        let clientInfo: [String: String]
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
        let classes = ANEBridge.availableClasses()
        let available = classes.values.contains(true)

        var deviceInfo: [String: String] = [:]
        if let info = ANEBridge.deviceInfo() {
            for (k, v) in info { deviceInfo[k] = "\(v)" }
        }

        var clientInfo: [String: String] = [:]
        if let info = ANEBridge.clientInfo() {
            for (k, v) in info { clientInfo[k] = "\(v)" }
        }

        return Reading(
            available: available,
            frameworkLoaded: ANEBridge.isLoaded,
            availableClasses: classes,
            deviceInfo: deviceInfo,
            clientInfo: clientInfo,
            timestamp: Date()
        )
    }
}
