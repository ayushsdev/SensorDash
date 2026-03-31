import SwiftUI

enum SensorCategory: String, CaseIterable, Identifiable {
    case battery = "Battery & Power"
    case smc = "Thermal & Fans"
    case display = "Display & Light"
    case multitouch = "Trackpad"
    case hidEvents = "HID Sensors"
    case motion = "Motion"
    case proximity = "Proximity / UWB"
    case neuralEngine = "Neural Engine"
    case depth = "Depth / LiDAR"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .battery: return "battery.100.bolt"
        case .smc: return "thermometer.medium"
        case .display: return "sun.max"
        case .multitouch: return "hand.point.up"
        case .hidEvents: return "sensor"
        case .motion: return "gyroscope"
        case .proximity: return "antenna.radiowaves.left.and.right"
        case .neuralEngine: return "brain"
        case .depth: return "cube.transparent"
        }
    }
}

enum SensorStatus: Sendable {
    case available
    case unavailable
    case restricted
    case error(String)

    var badge: Text? {
        switch self {
        case .available: return nil
        case .unavailable: return Text("N/A")
        case .restricted: return Text("Restricted")
        case .error: return Text("Error")
        }
    }

    var color: Color {
        switch self {
        case .available: return .green
        case .unavailable: return .gray
        case .restricted: return .orange
        case .error: return .red
        }
    }
}
