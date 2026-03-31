import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "gauge.with.dots.needle.33percent")
                Text("SensorDash")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)

            Divider()

            // Battery
            if let b = appState.dashboard.batteryReading {
                HStack {
                    Image(systemName: b.isCharging ? "battery.100.bolt" : "battery.75")
                        .foregroundStyle(b.currentCapacity > 20 ? .green : .red)
                    Text("Battery")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(b.currentCapacity)%")
                        .font(.system(.body, design: .monospaced, weight: .bold))
                    if b.isCharging {
                        Text("Charging")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            // Temperatures
            if let s = appState.dashboard.smcReading {
                HStack {
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(s.cpuTemperature > 80 ? .red : s.cpuTemperature > 60 ? .orange : .green)
                    Text("CPU")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f°C", s.cpuTemperature))
                        .font(.system(.body, design: .monospaced, weight: .bold))
                }
                if let fan = s.fanSpeeds.first {
                    HStack {
                        Image(systemName: "fan")
                            .foregroundStyle(.blue)
                        Text("Fan")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(fan.actualRPM) RPM")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }

            // Brightness
            if let d = appState.dashboard.displayReading, let first = d.displays.first {
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundStyle(.yellow)
                    Text("Brightness")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", first.brightness * 100))
                        .font(.system(.body, design: .monospaced))
                }
            }

            // ALS
            if let h = appState.dashboard.hidEventReading, let lux = h.ambientLightLux {
                HStack {
                    Image(systemName: "sun.min")
                        .foregroundStyle(.orange)
                    Text("Ambient Light")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f lux", lux))
                        .font(.system(.body, design: .monospaced))
                }
            }

            Divider()

            // Sensor Status
            HStack(spacing: 8) {
                ForEach(SensorCategory.allCases) { cat in
                    let status = appState.dashboard.status(for: cat)
                    Circle()
                        .fill(status.color)
                        .frame(width: 6, height: 6)
                        .help(cat.rawValue)
                }
                Spacer()
                Text("\(SensorCategory.allCases.count) sensors")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            Button {
                openWindow(id: "dashboard")
            } label: {
                Label("Open Dashboard", systemImage: "rectangle.on.rectangle")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
        }
        .padding()
        .frame(width: 280)
    }
}
