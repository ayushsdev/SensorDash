import Foundation

actor SMCProvider {
    struct FanReading: Sendable {
        let id: Int
        let actualRPM: Int
        let minRPM: Int
        let maxRPM: Int
    }

    struct Reading: Sendable {
        let cpuTemperature: Double
        let gpuTemperature: Double
        let ambientTemperature: Double
        let memoryTemperature: Double
        let palmRestTemperature: Double
        let wirelessTemperature: Double
        let fanSpeeds: [FanReading]
        let cpuPower: Double
        let gpuPower: Double
        let systemPower: Double
        let keyCount: UInt32
        let supportsHPM: Bool
        let supportsSilentRunning: Bool
        let timestamp: Date
    }

    private var isRunning = false
    private var conn: io_connect_t = 0

    func start() -> AsyncStream<Reading> {
        isRunning = true
        let openResult = SMCOpen(&conn)

        return AsyncStream { continuation in
            Task { [weak self] in
                guard let self else { return }
                let c = await self.conn
                guard openResult == KERN_SUCCESS else {
                    continuation.finish()
                    return
                }
                while await self.isRunning {
                    let reading = Self.read(conn: c)
                    continuation.yield(reading)
                    try? await Task.sleep(for: .seconds(1))
                }
                SMCClose(c)
                continuation.finish()
            }
        }
    }

    func stop() {
        isRunning = false
    }

    private static func read(conn: io_connect_t) -> Reading {
        let fanCount = SMCGetFanCount(conn)
        var fans: [FanReading] = []
        for i in 0..<fanCount {
            fans.append(FanReading(
                id: Int(i),
                actualRPM: Int(SMCGetFanRPM(conn, i)),
                minRPM: Int(SMCGetFanMinRPM(conn, i)),
                maxRPM: Int(SMCGetFanMaxRPM(conn, i))
            ))
        }

        // Try multiple temperature keys for Apple Silicon compatibility
        let cpuTemp = bestTemp(conn, keys: ["TC0P", "TC0D", "TC0E", "Tp09", "Tp0T"])
        let gpuTemp = bestTemp(conn, keys: ["TG0P", "TG0D", "Tg05", "Tg0D"])
        let ambientTemp = bestTemp(conn, keys: ["TA0P", "TA0p", "TaLP"])
        let memTemp = bestTemp(conn, keys: ["Tm0P", "TM0P", "Tm0p"])
        let palmTemp = bestTemp(conn, keys: ["Ts0P", "Ts0p"])
        let wirelessTemp = bestTemp(conn, keys: ["TW0P", "Tw0P"])

        let cpuPower = SMCGetPower(conn, "PCPT")
        let gpuPower = SMCGetPower(conn, "PCPG")
        let sysPower = SMCGetPower(conn, "PSTR")

        return Reading(
            cpuTemperature: cpuTemp,
            gpuTemperature: gpuTemp,
            ambientTemperature: ambientTemp,
            memoryTemperature: memTemp,
            palmRestTemperature: palmTemp,
            wirelessTemperature: wirelessTemp,
            fanSpeeds: fans,
            cpuPower: cpuPower > 0 ? cpuPower : 0,
            gpuPower: gpuPower > 0 ? gpuPower : 0,
            systemPower: sysPower > 0 ? sysPower : 0,
            keyCount: SMCGetKeyCount(conn),
            supportsHPM: IOPMBridge.supportsHPM?() ?? false,
            supportsSilentRunning: IOPMBridge.supportsSilentRunning?() ?? false,
            timestamp: Date()
        )
    }

    /// Try multiple SMC keys and return the first valid temperature.
    private static func bestTemp(_ conn: io_connect_t, keys: [String]) -> Double {
        for key in keys {
            let t = SMCGetTemperature(conn, key)
            if t > 0 && t < 150 { return t }
        }
        return 0
    }
}
