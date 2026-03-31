import SwiftUI
import CoreBluetooth

/// BLE Scanner using CBCentralManager
class BLEScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [BLEDevice] = []
    @Published var isScanning = false
    @Published var bluetoothState: String = "Unknown"

    struct BLEDevice: Identifiable {
        let id: UUID
        let name: String
        let rssi: Int
        let lastSeen: Date
    }

    private var central: CBCentralManager?
    private var deviceMap: [UUID: BLEDevice] = [:]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard central?.state == .poweredOn else { return }
        deviceMap.removeAll()
        devices.removeAll()
        central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
    }

    func stopScan() {
        central?.stopScan()
        isScanning = false
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: bluetoothState = "Powered On"
        case .poweredOff: bluetoothState = "Powered Off"
        case .unauthorized: bluetoothState = "Unauthorized"
        case .unsupported: bluetoothState = "Unsupported"
        default: bluetoothState = "Unknown"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let device = BLEDevice(
            id: peripheral.identifier,
            name: peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown",
            rssi: RSSI.intValue,
            lastSeen: Date()
        )
        deviceMap[peripheral.identifier] = device
        // Sort by RSSI (strongest first), limit to 30
        devices = Array(deviceMap.values.sorted { $0.rssi > $1.rssi }.prefix(30))
    }
}

struct ProximityDetailView: View {
    @Environment(AppState.self) var appState
    @StateObject private var bleScanner = BLEScanner()

    private var r: ProximityProvider.Reading? { appState.dashboard.proximityReading }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - BLE Scanner
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "bluetooth").font(.title2).foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Bluetooth RSSI Scanner").font(.title2.bold())
                                Text("Scan for nearby BLE devices and see signal strength").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack {
                                Text("\(bleScanner.devices.count)")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(.blue)
                                Text("devices").font(.caption2).foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Bluetooth: \(bleScanner.bluetoothState)")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(bleScanner.isScanning ? "Stop Scan" : "Start Scan") {
                                if bleScanner.isScanning { bleScanner.stopScan() } else { bleScanner.startScan() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(bleScanner.isScanning ? .red : .blue)
                        }

                        if bleScanner.isScanning {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Scanning...").font(.caption).foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(4)
                }

                // MARK: - Device List with Signal Bars
                if !bleScanner.devices.isEmpty {
                    GroupBox("Nearby Devices") {
                        ForEach(bleScanner.devices) { device in
                            HStack(spacing: 10) {
                                // Signal strength bars
                                signalBars(rssi: device.rssi)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.system(.body, weight: .medium))
                                        .lineLimit(1)
                                    Text(String(format: "RSSI: %d dBm • ~%.1fm", device.rssi, estimateDistance(rssi: device.rssi)))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(device.rssi) dBm")
                                    .font(.system(.body, design: .monospaced, weight: .bold))
                                    .foregroundStyle(rssiColor(device.rssi))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - Proximity Framework
                if let r {
                    GroupBox("Proximity Framework (Private)") {
                        SensorRow(label: "Framework Loaded", value: r.frameworkLoaded ? "Yes" : "No")
                        SensorRow(label: "UWB Chip", value: r.chipAvailable ? "Available" : "Not Found")

                        if !r.chipInfo.isEmpty {
                            ForEach(Array(r.chipInfo.keys.sorted()), id: \.self) { key in
                                SensorRow(label: key, value: r.chipInfo[key] ?? "")
                            }
                        }
                    }

                    GroupBox("Private Classes (\(r.availableClasses.filter(\.value).count)/\(r.availableClasses.count))") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                            ForEach(r.availableClasses.sorted(by: { $0.key < $1.key }), id: \.key) { name, ok in
                                HStack(spacing: 4) {
                                    Circle().fill(ok ? .green : .red.opacity(0.4)).frame(width: 7, height: 7)
                                    Text(name).font(.system(.caption2, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func signalBars(rssi: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                let threshold = -90 + i * 20 // -90, -70, -50, -30
                RoundedRectangle(cornerRadius: 1)
                    .fill(rssi >= threshold ? rssiColor(rssi) : .gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(8 + i * 4))
            }
        }
        .frame(width: 24, height: 24, alignment: .bottom)
    }

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi >= -50 { return .green }
        if rssi >= -70 { return .yellow }
        if rssi >= -85 { return .orange }
        return .red
    }

    private func estimateDistance(rssi: Int) -> Double {
        // Simple log-distance path loss model
        let txPower: Double = -59 // typical BLE TX power at 1m
        let n: Double = 2.5 // path loss exponent
        return pow(10, (txPower - Double(rssi)) / (10 * n))
    }
}
