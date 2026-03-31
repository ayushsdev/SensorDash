import SwiftUI

struct HIDEventDetailView: View {
    @Environment(AppState.self) var appState

    private var r: HIDEventProvider.Reading? { appState.dashboard.hidEventReading }

    var body: some View {
        ScrollView {
            if let r {
                VStack(spacing: 20) {
                    // MARK: - Ambient Light Meter
                    GroupBox {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Ambient Light Sensor")
                                    .font(.title2.bold())
                                Spacer()
                                if let lux = r.ambientLightLux {
                                    Text(String(format: "%.0f lux", lux))
                                        .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                                        .foregroundStyle(.yellow)
                                }
                            }

                            if let lux = r.ambientLightLux {
                                // Light meter bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [.gray, .yellow, .orange, .white],
                                                startPoint: .leading, endPoint: .trailing
                                            ).opacity(0.3))
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [.gray, .yellow, .orange],
                                                startPoint: .leading, endPoint: .trailing
                                            ))
                                            .frame(width: geo.size.width * CGFloat(min(lux / 100000, 1.0)))
                                            .animation(.easeOut, value: lux)
                                    }
                                }
                                .frame(height: 24)

                                HStack {
                                    Text("Dark").font(.caption2)
                                    Spacer()
                                    Text(luxDescription(lux)).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Bright").font(.caption2)
                                }
                            } else {
                                Text("ALS requires elevated privileges (root) on modern macOS")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(4)
                    }

                    SparklineChart(title: "Ambient Light History", samples: appState.dashboard.alsHistory.samples, unit: "lux", color: .yellow, height: 80)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // MARK: - Event Type Grid
                    GroupBox("IOHIDEvent Types — \(r.availableEventTypes.count) Create* Functions Found") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(r.availableEventTypes, id: \.self) { type in
                                HStack(spacing: 4) {
                                    Image(systemName: iconForEventType(type))
                                        .font(.caption2)
                                        .foregroundStyle(colorForEventType(type))
                                    Text(type)
                                        .font(.system(.caption2, design: .monospaced))
                                    Spacer()
                                }
                                .padding(4)
                                .background(colorForEventType(type).opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }

                    // MARK: - Event Type Constants Reference
                    GroupBox("IOHIDEvent Type IDs") {
                        let types: [(String, Int32, String)] = [
                            ("AmbientLightSensor", 12, "sun.max"),
                            ("Accelerometer", 13, "arrow.up.and.down"),
                            ("Gyro", 20, "gyroscope"),
                            ("Compass", 21, "location.north"),
                            ("AtmosphericPressure", 30, "barometer"),
                            ("Biometric", 28, "touchid"),
                            ("Proximity", 14, "sensor"),
                            ("Temperature", 15, "thermometer"),
                            ("Force", 31, "hand.tap"),
                            ("Brightness", 36, "sun.min"),
                            ("HeartRate", 38, "heart"),
                            ("Digitizer", 11, "hand.draw"),
                            ("Keyboard", 3, "keyboard"),
                            ("GameController", 34, "gamecontroller"),
                            ("MotionActivity", 32, "figure.walk"),
                        ]
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(types, id: \.0) { name, id, icon in
                                HStack(spacing: 6) {
                                    Image(systemName: icon).frame(width: 16)
                                    Text(name).font(.system(.caption, design: .monospaced))
                                    Spacer()
                                    Text("= \(id)").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                                }
                                .padding(4)
                            }
                        }
                    }
                }
                .padding()
            } else {
                ProgressView("Reading HID sensors...")
            }
        }
    }

    private func luxDescription(_ lux: Double) -> String {
        switch lux {
        case ..<10: return "Very dark"
        case ..<50: return "Dim room"
        case ..<200: return "Indoor"
        case ..<1000: return "Bright indoor"
        case ..<10000: return "Overcast"
        case ..<50000: return "Daylight"
        default: return "Direct sunlight"
        }
    }

    private func iconForEventType(_ type: String) -> String {
        switch type {
        case "AmbientLightSensor": return "sun.max"
        case "Accelerometer": return "arrow.up.and.down"
        case "Gyro": return "gyroscope"
        case "Compass": return "location.north"
        case "AtmosphericPressure": return "barometer"
        case "Biometric": return "touchid"
        case "Force", "ForceStage": return "hand.tap"
        case "HeartRate": return "heart"
        case "Proximity", "ProximityLevel": return "sensor"
        case "GameController": return "gamecontroller"
        case "Keyboard": return "keyboard"
        case "Mouse": return "computermouse"
        default: return "circle.fill"
        }
    }

    private func colorForEventType(_ type: String) -> Color {
        switch type {
        case "AmbientLightSensor", "Brightness": return .yellow
        case "Accelerometer", "Gyro", "Compass": return .blue
        case "AtmosphericPressure": return .cyan
        case "Biometric", "HeartRate": return .red
        case "Force", "ForceStage": return .purple
        case "GameController": return .green
        default: return .gray
        }
    }
}
