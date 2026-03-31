import SwiftUI

struct MultitouchDetailView: View {
    @Environment(AppState.self) var appState
    @State private var drawingMode = false
    @State private var drawingPaths: [DrawingPoint] = []
    @State private var gestureLog: [String] = []
    @State private var lastContactCount = 0

    struct DrawingPoint: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let color: Color
        let size: CGFloat
    }

    private var r: MultitouchProvider.Reading? { appState.dashboard.multitouchReading }

    var body: some View {
        ScrollView {
            if let r {
                if !r.frameworkLoaded {
                    UnavailableView(sensor: "MultitouchSupport", reason: "Could not load MultitouchSupport.framework")
                } else {
                    VStack(spacing: 20) {
                        // MARK: - Live Trackpad Canvas
                        GroupBox {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Live Trackpad")
                                        .font(.title2.bold())
                                    Spacer()
                                    Text("\(r.activeContacts.count) fingers")
                                        .font(.system(.title3, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                    Toggle("Draw", isOn: $drawingMode)
                                        .toggleStyle(.switch)
                                        .controlSize(.small)
                                    if drawingMode {
                                        Button("Clear") { drawingPaths.removeAll() }
                                            .controlSize(.small)
                                    }
                                }
                                Text(drawingMode ? "Drawing mode — finger trails persist" : "Touch your trackpad to see live finger data")
                                    .font(.caption).foregroundStyle(.secondary)

                                trackpadCanvas(contacts: r.activeContacts)
                                    .frame(height: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .onChange(of: r.activeContacts.count) { old, new in
                                        detectGestures(oldCount: old, newCount: new, contacts: r.activeContacts)
                                    }
                            }
                        }

                        // MARK: - Haptic Feedback Test
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "hand.tap.fill").font(.title2).foregroundStyle(.purple)
                                    VStack(alignment: .leading) {
                                        Text("Haptic Feedback Test").font(.headline)
                                        Text("Tap to fire Force Touch haptic actuations via MTActuatorActuate")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                HStack(spacing: 8) {
                                    hapticButton("Weak", actuationID: 1, color: .blue)
                                    hapticButton("Medium", actuationID: 2, color: .purple)
                                    hapticButton("Strong", actuationID: 3, color: .red)
                                    hapticButton("Click", actuationID: 6, color: .orange)
                                    hapticButton("Buzz", actuationID: 15, color: .green)
                                }
                            }
                            .padding(4)
                        }

                        // MARK: - Gesture Log
                        GroupBox {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Gesture Log").font(.headline)
                                    Spacer()
                                    Button("Clear") { gestureLog.removeAll() }
                                        .controlSize(.small)
                                }
                                if gestureLog.isEmpty {
                                    Text("Touch the trackpad to see gesture events...")
                                        .foregroundStyle(.tertiary).font(.caption)
                                } else {
                                    ForEach(Array(gestureLog.suffix(10).enumerated()), id: \.offset) { _, entry in
                                        Text(entry)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }

                        // MARK: - Per-Finger Data
                        if !r.activeContacts.isEmpty {
                            GroupBox("Finger Data") {
                                ForEach(r.activeContacts, id: \.identifier) { c in
                                    fingerCard(c)
                                    if c.identifier != r.activeContacts.last?.identifier { Divider() }
                                }
                            }
                        }

                        // MARK: - API Availability
                        GroupBox("MultitouchSupport APIs (\(apiList.filter(\.1).count)/\(apiList.count) available)") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                                ForEach(apiList, id: \.0) { name, ok in
                                    HStack(spacing: 4) {
                                        Circle().fill(ok ? .green : .red.opacity(0.4)).frame(width: 7, height: 7)
                                        Text(name).font(.system(.caption2, design: .monospaced)).lineLimit(1)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView("Reading trackpad...")
            }
        }
    }

    // MARK: - Haptic Button
    private func hapticButton(_ label: String, actuationID: Int32, color: Color) -> some View {
        Button(label) {
            fireHaptic(actuationID: actuationID)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }

    private func fireHaptic(actuationID: Int32) {
        // MTActuatorCreateFromDeviceID takes a numeric device ID.
        // On Apple Silicon Macs the built-in trackpad is typically device ID 0 or we can
        // try small IDs. We don't call MTActuatorGetDeviceID on an MTDeviceRef (that crashes).
        guard let create = MTBridge.actuatorCreateFromDeviceID else { return }

        // Try device IDs 0 through 3 to find one that works
        for deviceID: UInt64 in 0...3 {
            guard let actuator = create(deviceID) else { continue }
            let openResult = MTBridge.actuatorOpen?(actuator) ?? -1
            guard openResult == 0 else { continue }
            _ = MTBridge.actuatorActuate?(actuator, actuationID, nil, 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                MTBridge.actuatorClose?(actuator)
            }
            return // success — stop trying
        }
    }

    // MARK: - Gesture Detection
    private func detectGestures(oldCount: Int, newCount: Int, contacts: [ContactSnapshot]) {
        let time = Date().formatted(date: .omitted, time: .standard)
        if newCount > oldCount {
            gestureLog.append("[\(time)] \(newCount)-finger touch DOWN")
        } else if newCount < oldCount && newCount == 0 {
            gestureLog.append("[\(time)] All fingers LIFTED (was \(oldCount))")
        } else if newCount < oldCount {
            gestureLog.append("[\(time)] Finger LIFTED → \(newCount) remaining")
        }
        lastContactCount = newCount
    }

    // MARK: - Trackpad Canvas
    private func trackpadCanvas(contacts: [ContactSnapshot]) -> some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.gray.opacity(0.15), .gray.opacity(0.05)], startPoint: .top, endPoint: .bottom))

                // Grid
                ForEach(1..<4, id: \.self) { i in
                    Path { p in let x = geo.size.width * CGFloat(i)/4; p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)) }
                        .stroke(.gray.opacity(0.15), lineWidth: 0.5)
                }

                // Drawing trails
                if drawingMode {
                    ForEach(drawingPaths) { pt in
                        Circle().fill(pt.color.opacity(0.5)).frame(width: pt.size, height: pt.size).position(x: pt.x, y: pt.y)
                    }
                }

                // Live contacts
                ForEach(contacts, id: \.identifier) { c in
                    let x = CGFloat(c.normalizedX) * geo.size.width
                    let y = CGFloat(1 - c.normalizedY) * geo.size.height
                    let sz = CGFloat(c.size) * 200 + 20

                    Circle().fill(fingerColor(c).opacity(0.2)).frame(width: sz*1.5, height: sz*1.5).position(x: x, y: y).blur(radius: 8)
                    Ellipse().fill(fingerColor(c).opacity(0.7))
                        .frame(width: CGFloat(c.majorAxis)*120+15, height: CGFloat(c.minorAxis)*120+15)
                        .rotationEffect(.degrees(Double(c.angle)))
                        .position(x: x, y: y)
                    Text("\(c.identifier)").font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(.white).position(x: x, y: y)
                }

                // Add drawing points
                let _ = {
                    if drawingMode {
                        for c in contacts where c.isActive {
                            let pt = DrawingPoint(
                                x: CGFloat(c.normalizedX) * geo.size.width,
                                y: CGFloat(1 - c.normalizedY) * geo.size.height,
                                color: fingerColor(c),
                                size: CGFloat(c.size) * 50 + 5
                            )
                            DispatchQueue.main.async { drawingPaths.append(pt) }
                        }
                    }
                }()

                if contacts.isEmpty && !drawingMode {
                    VStack {
                        Image(systemName: "hand.tap").font(.system(size: 40)).foregroundStyle(.tertiary)
                        Text("Touch the trackpad").foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func fingerColor(_ c: ContactSnapshot) -> Color {
        let colors: [Color] = [.cyan, .blue, .purple, .pink, .orange, .green, .red, .yellow, .mint, .indigo]
        return colors[abs(Int(c.identifier)) % colors.count]
    }

    private func fingerCard(_ c: ContactSnapshot) -> some View {
        HStack(spacing: 16) {
            Circle().fill(fingerColor(c)).frame(width: 30, height: 30)
                .overlay { Text("\(c.identifier)").font(.caption.bold()).foregroundStyle(.white) }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "Pos: (%.3f, %.3f)", c.normalizedX, c.normalizedY))
                Text(String(format: "Size: %.3f  Angle: %.1f°", c.size, c.angle))
            }.font(.system(.caption, design: .monospaced))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "Major: %.2f", c.majorAxis))
                Text(String(format: "Minor: %.2f", c.minorAxis))
            }.font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Text(c.isActive ? "Active" : "Lifted").font(.caption.bold()).foregroundStyle(c.isActive ? .green : .gray)
        }.padding(.vertical, 4)
    }

    private var apiList: [(String, Bool)] {
        [
            ("MTDeviceCreateDefault", MTBridge.deviceCreateDefault != nil),
            ("MTDeviceCreateList", MTBridge.deviceCreateList != nil),
            ("MTDeviceOpen", MTBridge.deviceOpen != nil),
            ("MTDeviceClose", MTBridge.deviceClose != nil),
            ("MTDeviceStart", MTBridge.deviceStartRunning != nil),
            ("MTDeviceStop", MTBridge.deviceStopRunning != nil),
            ("MTRegisterContactFrameCallback", MTBridge.registerContactFrameCallback != nil),
            ("MTUnregisterContactFrameCallback", MTBridge.unregisterContactFrameCallback != nil),
            ("MTDeviceDriverIsReady", MTBridge.deviceDriverIsReady != nil),
            ("MTContact_getEllipseEccentricity", MTBridge.contactGetEllipseEccentricity != nil),
            ("MTContact_getEllipseMeanRadius", MTBridge.contactGetEllipseMeanRadius != nil),
            ("MTContact_getCentroidPixel", MTBridge.contactGetCentroidPixel != nil),
            ("MTActuatorCreateFromDeviceID", MTBridge.actuatorCreateFromDeviceID != nil),
            ("MTActuatorOpen", MTBridge.actuatorOpen != nil),
            ("MTActuatorActuate", MTBridge.actuatorActuate != nil),
            ("MTActuatorClose", MTBridge.actuatorClose != nil),
            ("MTDeviceBeginRecordingToFile", MTBridge.deviceBeginRecordingToFile != nil),
            ("MTDeviceDispatchScrollWheel", MTBridge.deviceDispatchScrollWheelEvent != nil),
        ]
    }
}
