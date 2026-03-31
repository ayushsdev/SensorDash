import Foundation
import CoreMotion

actor MotionProvider {
    struct Reading: Sendable {
        let isAvailable: Bool

        // Accelerometer
        let accelX: Double?
        let accelY: Double?
        let accelZ: Double?

        // Gyroscope
        let gyroX: Double?
        let gyroY: Double?
        let gyroZ: Double?

        // Device Motion (fused)
        let pitch: Double?
        let roll: Double?
        let yaw: Double?

        // Barometric Altimeter
        let pressure: Double?
        let relativeAltitude: Double?

        // Headphone Motion
        let headphoneMotionAvailable: Bool
        let headphonePitch: Double?
        let headphoneRoll: Double?
        let headphoneYaw: Double?

        // Private class availability
        let privateClassAvailability: [String: Bool]

        let timestamp: Date
    }

    private var isRunning = false
    private let headphoneManager = CMHeadphoneMotionManager()

    // Use NSClassFromString to access CMMotionManager on macOS where it may be restricted
    private static let motionManagerClass: AnyClass? = NSClassFromString("CMMotionManager")

    private var motionManager: NSObject?
    private var latestPressure: Double?
    private var latestAltitude: Double?

    func start() -> AsyncStream<Reading> {
        isRunning = true

        // Try to create CMMotionManager via runtime
        if let cls = Self.motionManagerClass as? NSObject.Type {
            motionManager = cls.init()
            // Start accelerometer
            if (motionManager?.value(forKey: "isAccelerometerAvailable") as? Bool) == true {
                motionManager?.setValue(0.1, forKey: "accelerometerUpdateInterval")
                motionManager?.perform(NSSelectorFromString("startAccelerometerUpdates"))
            }
            // Start gyro
            if (motionManager?.value(forKey: "isGyroAvailable") as? Bool) == true {
                motionManager?.setValue(0.1, forKey: "gyroUpdateInterval")
                motionManager?.perform(NSSelectorFromString("startGyroUpdates"))
            }
            // Start device motion
            if (motionManager?.value(forKey: "isDeviceMotionAvailable") as? Bool) == true {
                motionManager?.setValue(0.1, forKey: "deviceMotionUpdateInterval")
                motionManager?.perform(NSSelectorFromString("startDeviceMotionUpdates"))
            }
        }

        // Headphone motion
        if headphoneManager.isDeviceMotionAvailable {
            headphoneManager.startDeviceMotionUpdates()
        }

        return AsyncStream { continuation in
            Task { [weak self] in
                while let self, await self.isRunning {
                    let reading = await self.readMotion()
                    continuation.yield(reading)
                    try? await Task.sleep(for: .milliseconds(100))
                }
                continuation.finish()
            }
        }
    }

    func stop() {
        isRunning = false
        motionManager?.perform(NSSelectorFromString("stopAccelerometerUpdates"))
        motionManager?.perform(NSSelectorFromString("stopGyroUpdates"))
        motionManager?.perform(NSSelectorFromString("stopDeviceMotionUpdates"))
        headphoneManager.stopDeviceMotionUpdates()
    }

    private func readMotion() -> Reading {
        // Read accelerometer
        var accelX: Double?, accelY: Double?, accelZ: Double?
        if let accelData = motionManager?.value(forKey: "accelerometerData") as? NSObject {
            if let accel = accelData.value(forKey: "acceleration") as? CMAcceleration {
                accelX = accel.x; accelY = accel.y; accelZ = accel.z
            }
        }

        // Read gyro
        var gyroX: Double?, gyroY: Double?, gyroZ: Double?
        if let gyroData = motionManager?.value(forKey: "gyroData") as? NSObject {
            if let rate = gyroData.value(forKey: "rotationRate") as? CMRotationRate {
                gyroX = rate.x; gyroY = rate.y; gyroZ = rate.z
            }
        }

        // Read device motion
        var pitch: Double?, roll: Double?, yaw: Double?
        if let dm = motionManager?.value(forKey: "deviceMotion") as? NSObject {
            if let attitude = dm.value(forKey: "attitude") as? NSObject {
                pitch = attitude.value(forKey: "pitch") as? Double
                roll = attitude.value(forKey: "roll") as? Double
                yaw = attitude.value(forKey: "yaw") as? Double
            }
        }

        // Headphone motion
        let hm = headphoneManager.deviceMotion
        let hasAnySensor = motionManager != nil || headphoneManager.isDeviceMotionAvailable

        return Reading(
            isAvailable: hasAnySensor,
            accelX: accelX, accelY: accelY, accelZ: accelZ,
            gyroX: gyroX, gyroY: gyroY, gyroZ: gyroZ,
            pitch: pitch, roll: roll, yaw: yaw,
            pressure: latestPressure,
            relativeAltitude: latestAltitude,
            headphoneMotionAvailable: headphoneManager.isDeviceMotionAvailable,
            headphonePitch: hm?.attitude.pitch,
            headphoneRoll: hm?.attitude.roll,
            headphoneYaw: hm?.attitude.yaw,
            privateClassAvailability: CoreMotionBridge.availableClasses(),
            timestamp: Date()
        )
    }
}
