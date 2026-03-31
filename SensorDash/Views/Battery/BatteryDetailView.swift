import SwiftUI
import IOKit.pwr_mgt

struct BatteryDetailView: View {
    @Environment(AppState.self) var appState
    @State private var preventSleep = false
    @State private var assertionID: IOPMAssertionID = 0

    private var r: BatteryProvider.Reading? { appState.dashboard.batteryReading }

    var body: some View {
        ScrollView {
            if let r {
                VStack(spacing: 20) {
                    // MARK: - Big Battery Visual
                    HStack(spacing: 40) {
                        batteryVisual(r)
                        VStack(alignment: .leading, spacing: 12) {
                            bigStat("\(r.currentCapacity)%", label: "Capacity", color: batteryColor(r.currentCapacity))
                            bigStat(String(format: "%.0f mV", r.voltage), label: "Voltage", color: .blue)
                            bigStat(String(format: "%.0f mA", r.amperage), label: "Amperage", color: r.amperage > 0 ? .green : .orange)
                            bigStat(String(format: "%.1f °C", r.temperature), label: "Temperature", color: r.temperature > 40 ? .red : .green)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // MARK: - Prevent Sleep Toggle (actual IOPMAssertion)
                    GroupBox {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Prevent Sleep")
                                    .font(.headline)
                                Text("Creates an IOPMAssertion to keep your Mac awake")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $preventSleep)
                                .toggleStyle(.switch)
                                .onChange(of: preventSleep) { _, on in
                                    if on {
                                        let reason = "SensorDash: User requested prevent sleep" as CFString
                                        IOPMAssertionCreateWithName(
                                            kIOPMAssertionTypeNoIdleSleep as CFString,
                                            IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                            reason,
                                            &assertionID
                                        )
                                    } else {
                                        IOPMAssertionRelease(assertionID)
                                        assertionID = 0
                                    }
                                }
                        }
                        .padding(4)
                    }

                    // MARK: - Cell Voltage Bars
                    if !r.cellVoltages.isEmpty {
                        GroupBox("Cell Voltages") {
                            HStack(spacing: 12) {
                                ForEach(Array(r.cellVoltages.enumerated()), id: \.offset) { i, v in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(cellColor(v))
                                            .frame(width: 40, height: CGFloat(v / 4500.0 * 120))
                                            .animation(.easeInOut, value: v)
                                        Text(String(format: "%.0f", v))
                                            .font(.system(.caption2, design: .monospaced))
                                        Text("Cell \(i+1)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(height: 150)
                            .padding()
                        }
                    }

                    // MARK: - Live Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statCard("Cycle Count", "\(r.cycleCount) / 1000", icon: "arrow.2.circlepath", color: r.cycleCount > 500 ? .orange : .green)
                        statCard("Design Cap", "\(r.designCapacity) mAh", icon: "battery.100", color: .blue)
                        statCard("Nominal Cap", "\(r.nominalCapacity) mAh", icon: "battery.75", color: .blue)
                        statCard("Charging", r.isCharging ? "Yes" : "No", icon: "bolt.fill", color: r.isCharging ? .green : .gray)
                        statCard("External", r.externalConnected ? "Connected" : "Disconnected", icon: "powerplug", color: r.externalConnected ? .green : .gray)
                        statCard("Time Left", r.timeRemaining > 0 ? "\(r.timeRemaining) min" : "—", icon: "clock", color: .purple)
                        statCard("Thermal Warn", "\(r.thermalWarningLevel)", icon: "thermometer.sun", color: r.thermalWarningLevel > 0 ? .red : .green)
                        statCard("Sleep OK", r.sleepEnabled ? "Yes" : "No", icon: "moon", color: .indigo)
                        statCard("User Active", r.userIsActive ? "Yes" : "No", icon: "person.fill", color: r.userIsActive ? .green : .gray)
                    }

                    // MARK: - History
                    SparklineChart(title: "Battery %", samples: appState.dashboard.batteryHistory.samples, unit: "%", color: .green, height: 80)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // MARK: - Power Assertions
                    if let pa = r.powerAssertions, !pa.isEmpty {
                        GroupBox("Active Power Assertions (\(pa.count) processes)") {
                            ForEach(Array(pa.keys.sorted().prefix(10)), id: \.self) { key in
                                SensorRow(label: key, value: "\(pa[key] ?? "")")
                            }
                        }
                    }
                }
                .padding()
            } else {
                ProgressView("Reading battery...")
            }
        }
    }

    // MARK: - Battery Visual
    private func batteryVisual(_ r: BatteryProvider.Reading) -> some View {
        ZStack {
            // Battery outline
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary, lineWidth: 3)
                .frame(width: 100, height: 180)
            // Battery tip
            RoundedRectangle(cornerRadius: 2)
                .fill(.secondary)
                .frame(width: 40, height: 8)
                .offset(y: -94)
            // Fill level
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 5)
                    .fill(batteryColor(r.currentCapacity).gradient)
                    .frame(width: 90, height: CGFloat(r.currentCapacity) / 100.0 * 170)
                    .animation(.easeInOut(duration: 0.5), value: r.currentCapacity)
            }
            .frame(width: 100, height: 175)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            // Percentage text
            Text("\(r.currentCapacity)%")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
            // Charging bolt
            if r.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .offset(y: 30)
            }
        }
    }

    private func batteryColor(_ pct: Int) -> Color {
        if pct > 50 { return .green }
        if pct > 20 { return .orange }
        return .red
    }

    private func cellColor(_ mv: Double) -> Color {
        if mv > 4100 { return .green }
        if mv > 3800 { return .orange }
        return .red
    }

    private func bigStat(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statCard(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.body, design: .monospaced, weight: .semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
