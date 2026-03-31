import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    // MARK: - Sensor Readings
    var batteryReading: BatteryProvider.Reading?
    var smcReading: SMCProvider.Reading?
    var displayReading: DisplayProvider.Reading?
    var multitouchReading: MultitouchProvider.Reading?
    var hidEventReading: HIDEventProvider.Reading?
    var motionReading: MotionProvider.Reading?
    var proximityReading: ProximityProvider.Reading?
    var aneReading: ANEProvider.Reading?
    var depthReading: DepthProvider.Reading?

    // MARK: - Availability
    var sensorStatus: [SensorCategory: SensorStatus] = [:]

    // MARK: - History Buffers
    let cpuTempHistory = RingBuffer(capacity: 300)
    let gpuTempHistory = RingBuffer(capacity: 300)
    let fanSpeedHistory = RingBuffer(capacity: 300)
    let batteryHistory = RingBuffer(capacity: 300)
    let brightnessHistory = RingBuffer(capacity: 300)
    let alsHistory = RingBuffer(capacity: 300)

    // MARK: - Providers
    private let batteryProvider = BatteryProvider()
    private let smcProvider = SMCProvider()
    private let displayProvider = DisplayProvider()
    private let multitouchProvider = MultitouchProvider()
    private let hidEventProvider = HIDEventProvider()
    private let motionProvider = MotionProvider()
    private let proximityProvider = ProximityProvider()
    private let aneProvider = ANEProvider()
    private let depthProvider = DepthProvider()

    // MARK: - Tasks
    private var tasks: [Task<Void, Never>] = []

    func status(for category: SensorCategory) -> SensorStatus {
        sensorStatus[category] ?? .available
    }

    func startAll() {
        guard tasks.isEmpty else { return }

        tasks.append(Task {
            for await reading in await batteryProvider.start() {
                self.batteryReading = reading
                self.batteryHistory.append(value: Double(reading.currentCapacity))
                self.sensorStatus[.battery] = .available
            }
        })

        tasks.append(Task {
            for await reading in await smcProvider.start() {
                self.smcReading = reading
                self.cpuTempHistory.append(value: reading.cpuTemperature)
                self.gpuTempHistory.append(value: reading.gpuTemperature)
                if let fan = reading.fanSpeeds.first {
                    self.fanSpeedHistory.append(value: Double(fan.actualRPM))
                }
                self.sensorStatus[.smc] = .available
            }
        })

        tasks.append(Task {
            for await reading in await displayProvider.start() {
                self.displayReading = reading
                if let first = reading.displays.first {
                    self.brightnessHistory.append(value: Double(first.brightness * 100))
                }
                self.sensorStatus[.display] = .available
            }
        })

        tasks.append(Task {
            for await reading in await multitouchProvider.start() {
                self.multitouchReading = reading
                self.sensorStatus[.multitouch] = .available
            }
        })

        tasks.append(Task {
            for await reading in await hidEventProvider.start() {
                self.hidEventReading = reading
                if let lux = reading.ambientLightLux {
                    self.alsHistory.append(value: lux)
                }
                self.sensorStatus[.hidEvents] = .available
            }
        })

        tasks.append(Task {
            for await reading in await motionProvider.start() {
                self.motionReading = reading
                self.sensorStatus[.motion] = reading.isAvailable ? .available : .unavailable
            }
        })

        tasks.append(Task {
            for await reading in await proximityProvider.start() {
                self.proximityReading = reading
                self.sensorStatus[.proximity] = reading.chipAvailable ? .available : .unavailable
            }
        })

        tasks.append(Task {
            for await reading in await aneProvider.start() {
                self.aneReading = reading
                self.sensorStatus[.neuralEngine] = reading.available ? .available : .unavailable
            }
        })

        tasks.append(Task {
            for await reading in await depthProvider.start() {
                self.depthReading = reading
                self.sensorStatus[.depth] = reading.available ? .available : .unavailable
            }
        })
    }

    func stopAll() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
