import SwiftUI

struct DisplayDetailView: View {
    @Environment(AppState.self) var appState
    @State private var brightnessOverride: Float?

    private var r: DisplayProvider.Reading? { appState.dashboard.displayReading }

    var body: some View {
        ScrollView {
            if let r {
                if !r.frameworkLoaded {
                    UnavailableView(sensor: "DisplayServices", reason: "Could not load DisplayServices.framework")
                } else {
                    VStack(spacing: 20) {
                        ForEach(Array(r.displays.enumerated()), id: \.offset) { i, display in
                            displayMiniApp(display, index: i)
                        }

                        // MARK: - API Explorer
                        GroupBox("DisplayServices API Explorer — \(availableCount) / \(totalCount) APIs available") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                ForEach(allAPIs, id: \.name) { api in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(api.available ? .green : .red.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                        Text(api.name)
                                            .font(.system(.caption, design: .monospaced))
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                }
                            }
                        }

                        SparklineChart(title: "Brightness History", samples: appState.dashboard.brightnessHistory.samples, unit: "%", color: .yellow, height: 80)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
            } else {
                ProgressView("Reading display sensors...")
            }
        }
    }

    // MARK: - Interactive Display Card
    private func displayMiniApp(_ d: DisplayProvider.DisplayReading, index: Int) -> some View {
        GroupBox {
            VStack(spacing: 16) {
                // Display icon + info
                HStack {
                    Image(systemName: d.isBuiltIn ? "macbook" : "display")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Display \(index + 1)")
                            .font(.title2.bold())
                        Text(d.isBuiltIn ? "Built-in Retina Display" : "External Display")
                            .foregroundStyle(.secondary)
                        Text(String(format: "ID: 0x%08X", d.displayID))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    // Big brightness number
                    Text(String(format: "%.0f%%", (brightnessOverride ?? d.brightness) * 100))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.yellow)
                }

                // MARK: - Interactive Brightness Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "sun.min")
                        Slider(value: Binding(
                            get: { Double(brightnessOverride ?? d.brightness) },
                            set: { newVal in
                                brightnessOverride = Float(newVal)
                                DSBridge.setBrightness?(d.displayID, Float(newVal))
                            }
                        ), in: 0...1)
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(.yellow)
                    }
                    Text("Drag to control brightness in real-time")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Quick brightness buttons
                HStack(spacing: 8) {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { pct in
                        Button("\(pct)%") {
                            let val = Float(pct) / 100.0
                            brightnessOverride = val
                            DSBridge.setBrightness?(d.displayID, val)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Spacer()
                    Button("Smooth 0→100") {
                        Task {
                            for i in stride(from: 0, through: 100, by: 2) {
                                let val = Float(i) / 100.0
                                brightnessOverride = val
                                DSBridge.setBrightness?(d.displayID, val)
                                try? await Task.sleep(for: .milliseconds(30))
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Divider()

                // Sensor data
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    miniStat("Linear", String(format: "%.4f", d.linearBrightness))
                    miniStat("Can Change", d.canChangeBrightness ? "Yes" : "No")
                    miniStat("Built-in", d.isBuiltIn ? "Yes" : "No")
                }
            }
            .padding(4)
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.body, design: .monospaced, weight: .semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - API catalog
    struct APIEntry: Identifiable {
        let name: String
        let available: Bool
        var id: String { name }
    }

    private var allAPIs: [APIEntry] {
        [
            APIEntry(name: "GetBrightness", available: DSBridge.getBrightness != nil),
            APIEntry(name: "SetBrightness", available: DSBridge.setBrightness != nil),
            APIEntry(name: "SetBrightnessSmooth", available: DSBridge.setBrightnessSmooth != nil),
            APIEntry(name: "SetBrightnessWithType", available: DSBridge.setBrightnessWithType != nil),
            APIEntry(name: "GetLinearBrightness", available: DSBridge.getLinearBrightness != nil),
            APIEntry(name: "SetLinearBrightness", available: DSBridge.setLinearBrightness != nil),
            APIEntry(name: "GetLinearBrightnessUsableRange", available: DSBridge.getLinearBrightnessUsableRange != nil),
            APIEntry(name: "GetBrightnessIncrement", available: DSBridge.getBrightnessIncrement != nil),
            APIEntry(name: "CanChangeBrightness", available: DSBridge.canChangeBrightness != nil),
            APIEntry(name: "NeedsBrightnessSmoothing", available: DSBridge.needsBrightnessSmoothing != nil),
            APIEntry(name: "CreateBrightnessTable", available: DSBridge.createBrightnessTable != nil),
            APIEntry(name: "HasAmbientLightComp", available: DSBridge.hasALC != nil),
            APIEntry(name: "ALCEnabled", available: DSBridge.alcEnabled != nil),
            APIEntry(name: "EnableALC", available: DSBridge.enableALC != nil),
            APIEntry(name: "CanResetAmbientLight", available: DSBridge.canResetAmbientLight != nil),
            APIEntry(name: "ResetAmbientLight", available: DSBridge.resetAmbientLight != nil),
            APIEntry(name: "ResetAmbientLightAll", available: DSBridge.resetAmbientLightAll != nil),
            APIEntry(name: "IsBuiltInDisplay", available: DSBridge.isBuiltInDisplay != nil),
            APIEntry(name: "IsSmartDisplay", available: DSBridge.isSmartDisplay != nil),
            APIEntry(name: "GetPowerMode", available: DSBridge.getPowerMode != nil),
            APIEntry(name: "SetPowerMode", available: DSBridge.setPowerMode != nil),
            APIEntry(name: "HasPowerButton", available: DSBridge.hasPowerButton != nil),
            APIEntry(name: "HasBrightnessButtons", available: DSBridge.hasBrightnessButtons != nil),
            APIEntry(name: "BezelButtonsLocked", available: DSBridge.bezelButtonsLocked != nil),
            APIEntry(name: "HasCommit", available: DSBridge.hasCommit != nil),
            APIEntry(name: "CommitSettings", available: DSBridge.commitSettings != nil),
            APIEntry(name: "SetToDefaults", available: DSBridge.setToDefaults != nil),
            APIEntry(name: "GetDynamicSlider", available: DSBridge.getDynamicSlider != nil),
            APIEntry(name: "HasTouchSwitchDisable", available: DSBridge.hasTouchSwitchDisable != nil),
            APIEntry(name: "HasOptionsAuth", available: DSBridge.hasOptionsAuthorization != nil),
            APIEntry(name: "ScreenVirtualTemp", available: DSBridge.setScreenVirtualTemperature != nil),
        ]
    }

    private var availableCount: Int { allAPIs.filter(\.available).count }
    private var totalCount: Int { allAPIs.count }
}
