import Foundation

// MARK: - Global state for C callback interop

struct ContactSnapshot: Sendable {
    let identifier: Int32
    let normalizedX: Float
    let normalizedY: Float
    let size: Float
    let pressure: Int32
    let angle: Float
    let majorAxis: Float
    let minorAxis: Float
    let isActive: Bool
    let state: Int32
}

private var globalContacts: [ContactSnapshot] = []
private let globalLock = NSLock()
var globalDevices: [UnsafeMutableRawPointer] = []
private var retainedDeviceList: CFArray? // prevent ARC from releasing the device list

/// C callback invoked by MultitouchSupport on every touch frame (~133Hz).
private let mtCallback: MTContactCallback = { device, data, count, timestamp, frame in
    guard let data, count > 0 else {
        globalLock.lock()
        globalContacts = []
        globalLock.unlock()
        return
    }

    let contactSize = MemoryLayout<MTContact>.stride
    var contacts: [ContactSnapshot] = []

    for i in 0..<Int(count) {
        let ptr = data.advanced(by: i * contactSize)
        let c = ptr.load(as: MTContact.self)
        contacts.append(ContactSnapshot(
            identifier: c.identifier,
            normalizedX: c.normalized.pos.x,
            normalizedY: c.normalized.pos.y,
            size: c.size,
            pressure: c.pressure,
            angle: c.angle,
            majorAxis: c.majorAxis,
            minorAxis: c.minorAxis,
            isActive: c.state == 4 || c.state == 3, // 3=touching, 4=pressing
            state: c.state
        ))
    }

    globalLock.lock()
    globalContacts = contacts
    globalLock.unlock()
}

// MARK: - MultitouchProvider

actor MultitouchProvider {
    typealias ContactReading = ContactSnapshot

    struct DeviceInfo: Sendable {
        let index: Int
        let isReady: Bool
    }

    struct Reading: Sendable {
        let devices: [DeviceInfo]
        let activeContacts: [ContactReading]
        let frameworkLoaded: Bool
        let timestamp: Date
    }

    private var isRunning = false
    private var registered = false

    func start() -> AsyncStream<Reading> {
        isRunning = true

        if !registered, MTBridge.isLoaded {
            Self.registerCallbacks()
            registered = true
        }

        return AsyncStream { continuation in
            Task { [weak self] in
                while let self, await self.isRunning {
                    let reading = Self.readMultitouch()
                    continuation.yield(reading)
                    try? await Task.sleep(for: .milliseconds(33))
                }
                continuation.finish()
            }
        }
    }

    func stop() {
        isRunning = false
        if registered {
            Self.unregisterCallbacks()
            registered = false
        }
    }

    // MARK: - Callback Registration

    private static func registerCallbacks() {
        guard let createList = MTBridge.deviceCreateList else { return }

        // Get the device list as CFArray and retain it
        guard let cfArray = createList() else { return }
        retainedDeviceList = cfArray

        let nsArray = cfArray as NSArray
        guard nsArray.count > 0 else { return }

        globalDevices = []

        for i in 0..<nsArray.count {
            // Each element is an opaque MTDeviceRef (CFType)
            let obj = nsArray[i]
            let device = Unmanaged<AnyObject>.passUnretained(obj as AnyObject).toOpaque()
            globalDevices.append(device)

            // 1. Open the device
            let openResult = MTBridge.deviceOpen?(device) ?? -1
            guard openResult == 0 else { continue }

            // 2. Register our callback
            MTBridge.registerContactFrameCallback?(device, mtCallback)

            // 3. Start the device — this is the critical missing step
            MTBridge.deviceStartRunning?(device, 0)
        }
    }

    private static func unregisterCallbacks() {
        for device in globalDevices {
            MTBridge.deviceStopRunning?(device)
            MTBridge.unregisterContactFrameCallback?(device, mtCallback)
            _ = MTBridge.deviceClose?(device)
        }
        globalDevices = []
        retainedDeviceList = nil
    }

    // MARK: - Read

    private static func readMultitouch() -> Reading {
        guard MTBridge.isLoaded else {
            return Reading(devices: [], activeContacts: [], frameworkLoaded: false, timestamp: Date())
        }

        var devices: [DeviceInfo] = []
        for (i, _) in globalDevices.enumerated() {
            devices.append(DeviceInfo(index: i, isReady: true))
        }

        globalLock.lock()
        let contacts = globalContacts
        globalLock.unlock()

        return Reading(
            devices: devices,
            activeContacts: contacts,
            frameworkLoaded: true,
            timestamp: Date()
        )
    }
}
