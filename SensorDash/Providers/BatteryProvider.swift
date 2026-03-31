import Foundation
import IOKit
import IOKit.ps

actor BatteryProvider {
    struct Reading: Sendable {
        // Basic
        let currentCapacity: Int
        let maxCapacity: Int
        let designCapacity: Int
        let nominalCapacity: Int
        let cycleCount: Int
        let voltage: Double
        let amperage: Double
        let temperature: Double
        let isCharging: Bool
        let fullyCharged: Bool
        let externalConnected: Bool
        let timeRemaining: Int

        // Per-cell
        let cellVoltages: [Double]

        // Advanced
        let chemID: Int
        let chargerData: [String: Any]
        let powerTelemetry: [String: Any]

        // System power info (safe public APIs only)
        let thermalWarningLevel: UInt32
        let sleepEnabled: Bool
        let userIsActive: Bool
        let powerAssertions: [String: Any]?
        let assertionsStatus: [String: Any]?

        let timestamp: Date
    }

    private var isRunning = false

    func start() -> AsyncStream<Reading> {
        isRunning = true
        return AsyncStream { continuation in
            Task { [weak self] in
                while let self, await self.isRunning {
                    let reading = Self.readBattery()
                    continuation.yield(reading)
                    try? await Task.sleep(for: .seconds(2))
                }
                continuation.finish()
            }
        }
    }

    func stop() {
        isRunning = false
    }

    private static func readBattery() -> Reading {
        var props: [String: Any] = [:]

        // Read from IORegistry (AppleSmartBattery) — safe public IOKit API
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != IO_OBJECT_NULL {
            var cfProps: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &cfProps, kCFAllocatorDefault, 0) == KERN_SUCCESS {
                props = (cfProps?.takeRetainedValue() as? [String: Any]) ?? [:]
            }
            IOObjectRelease(service)
        }

        // Extract cell voltages
        var cellVoltages: [Double] = []
        if let bdata = props["BatteryData"] as? [String: Any],
           let cells = bdata["CellVoltage"] as? [Any] {
            cellVoltages = cells.compactMap { ($0 as? NSNumber)?.doubleValue }
        }

        // Charger data
        let chargerData = props["ChargerData"] as? [String: Any] ?? [:]
        let powerTelemetry = props["PowerTelemetryData"] as? [String: Any] ?? [:]

        // Safe IOPM functions (these are public API via IOPMLib.h)
        var thermalLevel: UInt32 = 0
        if let fn = IOPMBridge.getThermalWarningLevel {
            _ = fn(&thermalLevel)
        }

        let sleepEnabled = IOPMBridge.sleepEnabled?() ?? false
        let userIsActive = IOPMBridge.userIsActive?() ?? false

        // Power assertions — use public IOPMLib API
        var assertionsDict: Unmanaged<CFDictionary>?
        var powerAssertions: [String: Any]? = nil
        if IOPMCopyAssertionsByProcess(&assertionsDict) == kIOReturnSuccess {
            powerAssertions = assertionsDict?.takeRetainedValue() as? [String: Any]
        }

        var statusDict: Unmanaged<CFDictionary>?
        var assertionsStatus: [String: Any]? = nil
        if IOPMCopyAssertionsStatus(&statusDict) == kIOReturnSuccess {
            assertionsStatus = statusDict?.takeRetainedValue() as? [String: Any]
        }

        return Reading(
            currentCapacity: props["CurrentCapacity"] as? Int ?? 0,
            maxCapacity: props["MaxCapacity"] as? Int ?? 100,
            designCapacity: (props["BatteryData"] as? [String: Any])?["DesignCapacity"] as? Int ?? props["DesignCapacity"] as? Int ?? 0,
            nominalCapacity: props["NominalChargeCapacity"] as? Int ?? 0,
            cycleCount: props["CycleCount"] as? Int ?? 0,
            voltage: (props["AppleRawBatteryVoltage"] as? Double ?? Double(props["AppleRawBatteryVoltage"] as? Int ?? 0)),
            amperage: Double(props["Amperage"] as? Int ?? 0),
            temperature: Double(props["Temperature"] as? Int ?? 0) / 100.0,
            isCharging: props["IsCharging"] as? Bool ?? false,
            fullyCharged: props["FullyCharged"] as? Bool ?? false,
            externalConnected: props["ExternalConnected"] as? Bool ?? false,
            timeRemaining: props["TimeRemaining"] as? Int ?? 0,
            cellVoltages: cellVoltages,
            chemID: (props["BatteryData"] as? [String: Any])?["ChemID"] as? Int ?? 0,
            chargerData: chargerData,
            powerTelemetry: powerTelemetry,
            thermalWarningLevel: thermalLevel,
            sleepEnabled: sleepEnabled,
            userIsActive: userIsActive,
            powerAssertions: powerAssertions,
            assertionsStatus: assertionsStatus,
            timestamp: Date()
        )
    }
}
