import SwiftUI
import Charts

struct SMCDetailView: View {
    @Environment(AppState.self) var appState
    @State private var stressTestRunning = false
    @State private var stressTasks: [Task<Void, Never>] = []
    @State private var tempAlert: Double = 85
    @State private var alertTriggered = false

    private var r: SMCProvider.Reading? { appState.dashboard.smcReading }

    var body: some View {
        ScrollView {
            if let r {
                VStack(spacing: 20) {
                    // MARK: - Temperature Dashboard
                    HStack(spacing: 20) {
                        tempCircle("CPU", temp: r.cpuTemperature, max: 110)
                        tempCircle("GPU", temp: r.gpuTemperature, max: 110)
                        tempCircle("Ambient", temp: r.ambientTemperature, max: 50)
                    }
                    .padding()
                    .background(alertTriggered ? Color.red.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .onChange(of: r.cpuTemperature) { _, newTemp in
                        alertTriggered = newTemp >= tempAlert
                    }

                    // MARK: - CPU Stress Test
                    GroupBox {
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text("CPU Stress Test")
                                        .font(.headline)
                                    Text("Spin up all CPU cores and watch temperatures + fans react")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(stressTestRunning ? "Stop" : "Heat it up!") {
                                    if stressTestRunning {
                                        stopStressTest()
                                    } else {
                                        startStressTest()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(stressTestRunning ? .red : .orange)
                            }
                            if stressTestRunning {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Stress test running on \(ProcessInfo.processInfo.activeProcessorCount) cores...")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(4)
                    }

                    // MARK: - Temperature Alert
                    GroupBox {
                        HStack {
                            Image(systemName: alertTriggered ? "exclamationmark.triangle.fill" : "bell")
                                .foregroundStyle(alertTriggered ? .red : .secondary)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Temperature Alert")
                                    .font(.headline)
                                Text("Flash red when CPU exceeds threshold")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f°C", tempAlert))
                                .font(.system(.body, design: .monospaced, weight: .bold))
                                .foregroundStyle(alertTriggered ? .red : .primary)
                            Slider(value: $tempAlert, in: 40...105, step: 5)
                                .frame(width: 150)
                        }
                        .padding(4)
                    }

                    // MARK: - Live Charts
                    HStack(spacing: 12) {
                        GroupBox("CPU Temperature") {
                            SparklineChart(title: "", samples: appState.dashboard.cpuTempHistory.samples, unit: "°C", color: .red, height: 100)
                        }
                        GroupBox("GPU Temperature") {
                            SparklineChart(title: "", samples: appState.dashboard.gpuTempHistory.samples, unit: "°C", color: .orange, height: 100)
                        }
                    }

                    // MARK: - Fans
                    if !r.fanSpeeds.isEmpty {
                        GroupBox("Fans") {
                            ForEach(r.fanSpeeds, id: \.id) { fan in
                                fanVisual(fan)
                            }
                        }
                    }

                    GroupBox("Fan Speed History") {
                        SparklineChart(title: "", samples: appState.dashboard.fanSpeedHistory.samples, unit: "RPM", color: .cyan, height: 80)
                    }

                    // MARK: - Power
                    GroupBox("Power Draw") {
                        HStack(spacing: 20) {
                            powerBar("CPU", watts: r.cpuPower, maxVal: 50, color: .red)
                            powerBar("GPU", watts: r.gpuPower, maxVal: 50, color: .orange)
                            powerBar("System", watts: r.systemPower, maxVal: 100, color: .blue)
                        }
                        .padding()
                    }

                    // Extra temps + SMC info
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        if r.memoryTemperature > 0 { miniTemp("Memory", r.memoryTemperature) }
                        if r.palmRestTemperature > 0 { miniTemp("Palm Rest", r.palmRestTemperature) }
                        if r.wirelessTemperature > 0 { miniTemp("Wireless", r.wirelessTemperature) }
                    }

                    GroupBox("SMC Info") {
                        SensorRow(label: "Total SMC Keys", value: "\(r.keyCount)")
                        SensorRow(label: "High Power Mode", value: r.supportsHPM ? "Supported" : "—")
                        SensorRow(label: "Silent Running", value: r.supportsSilentRunning ? "Supported" : "—")
                    }
                }
                .padding()
            } else {
                ProgressView("Connecting to SMC...")
            }
        }
    }

    // MARK: - Stress Test
    private func startStressTest() {
        stressTestRunning = true
        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        for _ in 0..<coreCount {
            let task = Task.detached(priority: .high) {
                while !Task.isCancelled {
                    // Busy loop — burns CPU
                    var x: Double = 1.0
                    for i in 0..<1_000_000 {
                        x = sin(x + Double(i))
                    }
                    _ = x
                }
            }
            stressTasks.append(task)
        }
    }

    private func stopStressTest() {
        stressTasks.forEach { $0.cancel() }
        stressTasks.removeAll()
        stressTestRunning = false
    }

    // MARK: - Sub-views (unchanged from before)
    private func tempCircle(_ label: String, temp: Double, max: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 10).frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: min(temp / max, 1.0))
                    .stroke(tempColor(temp).gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: temp)
                VStack(spacing: 0) {
                    Text(String(format: "%.0f°", temp))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(tempColor(temp))
                    Text("°C").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func fanVisual(_ fan: SMCProvider.FanReading) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "fan.fill").font(.title).foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text("Fan \(fan.id)").font(.headline)
                    Text("\(fan.actualRPM) RPM")
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(fan.actualRPM > fan.maxRPM / 2 ? .orange : .cyan)
                }
                Spacer()
                Text("\(Int(Double(fan.actualRPM) / Double(Swift.max(fan.maxRPM, 1)) * 100))%")
                    .font(.system(.title2, design: .monospaced)).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(fan.actualRPM), total: Double(Swift.max(fan.maxRPM, 1)))
                .tint(fan.actualRPM > fan.maxRPM / 2 ? .orange : .cyan)
            HStack {
                Text("Min: \(fan.minRPM)"); Spacer(); Text("Max: \(fan.maxRPM)")
            }.font(.caption2).foregroundStyle(.tertiary)
        }.padding(8)
    }

    private func powerBar(_ label: String, watts: Double, maxVal: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4).fill(color.gradient)
                .frame(width: 50, height: Swift.max(CGFloat(watts / maxVal * 100), 2))
                .animation(.easeInOut, value: watts)
            Text(String(format: "%.1fW", watts)).font(.system(.caption, design: .monospaced, weight: .bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(height: 130).frame(maxWidth: .infinity)
    }

    private func miniTemp(_ label: String, _ temp: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f°C", temp)).font(.system(.body, design: .monospaced, weight: .bold)).foregroundStyle(tempColor(temp))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.padding(8).frame(maxWidth: .infinity).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func tempColor(_ t: Double) -> Color {
        if t > 90 { return .red }; if t > 70 { return .orange }; if t > 50 { return .yellow }; return .green
    }
}
