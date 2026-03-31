import SwiftUI

struct MotionDetailView: View {
    @Environment(AppState.self) var appState
    @State private var ballX: CGFloat = 150
    @State private var ballY: CGFloat = 150
    @State private var ballVX: CGFloat = 0
    @State private var ballVY: CGFloat = 0
    @State private var shakeDetected = false
    @State private var shakeCount = 0
    @State private var lastAccelMag: Double = 0
    @State private var recording = false
    @State private var recordedSamples: [(Date, Double, Double, Double)] = []

    private var r: MotionProvider.Reading? { appState.dashboard.motionReading }

    var body: some View {
        ScrollView {
            if let r {
                VStack(spacing: 20) {
                    // MARK: - Ball Game
                    if r.accelX != nil {
                        GroupBox {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Accelerometer Ball").font(.title2.bold())
                                    Spacer()
                                    Text("Tilt your MacBook!").font(.caption).foregroundStyle(.secondary)
                                }
                                ballGame(r: r)
                                    .frame(height: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // MARK: - Shake Detector
                    GroupBox {
                        HStack {
                            Image(systemName: shakeDetected ? "waveform.path.ecg" : "iphone.gen3.radiowaves.left.and.right")
                                .font(.title)
                                .foregroundStyle(shakeDetected ? .red : .secondary)
                                .scaleEffect(shakeDetected ? 1.3 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: shakeDetected)
                            VStack(alignment: .leading) {
                                Text("Shake Detector").font(.headline)
                                Text(shakeDetected ? "SHAKE DETECTED!" : "Shake your MacBook to trigger")
                                    .font(.caption)
                                    .foregroundStyle(shakeDetected ? .red : .secondary)
                            }
                            Spacer()
                            VStack {
                                Text("\(shakeCount)")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(shakeDetected ? .red : .primary)
                                Text("shakes").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(4)
                        .onChange(of: r.accelX) { _, _ in
                            detectShake(r: r)
                        }
                    }

                    // MARK: - Motion Recording
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Motion Recorder").font(.headline)
                                Spacer()
                                Button(recording ? "Stop" : "Record") {
                                    if recording {
                                        recording = false
                                    } else {
                                        recordedSamples.removeAll()
                                        recording = true
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(recording ? .red : .blue)
                            }
                            if recording {
                                HStack {
                                    Circle().fill(.red).frame(width: 8, height: 8)
                                    Text("Recording... \(recordedSamples.count) samples")
                                        .font(.caption).foregroundStyle(.red)
                                }
                                .onChange(of: r.accelX) { _, _ in
                                    if recording, let x = r.accelX, let y = r.accelY, let z = r.accelZ {
                                        recordedSamples.append((Date(), x, y, z))
                                    }
                                }
                            }
                            if !recordedSamples.isEmpty && !recording {
                                Text("\(recordedSamples.count) samples recorded")
                                    .font(.caption).foregroundStyle(.green)
                                SparklineChart(
                                    title: "Recorded Accel X",
                                    samples: recordedSamples.map { TimeSample(date: $0.0, value: $0.1) },
                                    unit: "g", color: .red, height: 60
                                )
                            }
                        }
                    }

                    // MARK: - 3-Axis Live
                    HStack(spacing: 16) {
                        if let x = r.accelX, let y = r.accelY, let z = r.accelZ {
                            axisGroup("Accelerometer", x: x, y: y, z: z, unit: "g")
                        }
                        if let x = r.gyroX, let y = r.gyroY, let z = r.gyroZ {
                            axisGroup("Gyroscope", x: x, y: y, z: z, unit: "rad/s")
                        }
                    }

                    // MARK: - Attitude
                    if let p = r.pitch, let ro = r.roll, let y = r.yaw {
                        GroupBox("Device Attitude") {
                            HStack(spacing: 30) {
                                attitudeCircle("Roll", angle: ro, color: .blue)
                                attitudeCircle("Pitch", angle: p, color: .red)
                                attitudeCircle("Yaw", angle: y, color: .green)
                            }
                            .padding()
                        }
                    }

                    // MARK: - Barometer
                    if r.pressure != nil || r.relativeAltitude != nil {
                        GroupBox("Barometric Altimeter") {
                            HStack(spacing: 30) {
                                if let p = r.pressure {
                                    VStack {
                                        Text(String(format: "%.2f", p)).font(.system(.title, design: .monospaced, weight: .bold)).foregroundStyle(.blue)
                                        Text("kPa").foregroundStyle(.secondary)
                                    }
                                }
                                if let a = r.relativeAltitude {
                                    VStack {
                                        Text(String(format: "%.2f", a)).font(.system(.title, design: .monospaced, weight: .bold)).foregroundStyle(.green)
                                        Text("meters").foregroundStyle(.secondary)
                                    }
                                }
                            }.padding()
                        }
                    }

                    // MARK: - AirPods
                    GroupBox("AirPods Head Tracking") {
                        if r.headphoneMotionAvailable, let p = r.headphonePitch, let ro = r.headphoneRoll, let y = r.headphoneYaw {
                            HStack(spacing: 20) {
                                axisBar("Pitch", value: p * 180 / .pi, range: -90...90, color: .red)
                                axisBar("Roll", value: ro * 180 / .pi, range: -180...180, color: .green)
                                axisBar("Yaw", value: y * 180 / .pi, range: -180...180, color: .blue)
                            }.padding()
                        } else {
                            Text("Connect AirPods Pro/Max for head tracking").foregroundStyle(.tertiary)
                        }
                    }

                    // MARK: - Private Classes
                    GroupBox("CoreMotion Private Classes (\(r.privateClassAvailability.filter(\.value).count)/\(r.privateClassAvailability.count))") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                            ForEach(r.privateClassAvailability.sorted(by: { $0.key < $1.key }), id: \.key) { name, ok in
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
            } else {
                ProgressView("Reading motion sensors...")
            }
        }
    }

    // MARK: - Ball Game
    private func ballGame(r: MotionProvider.Reading) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.8))

                // Walls
                RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.3), lineWidth: 2)

                // Ball
                Circle()
                    .fill(RadialGradient(colors: [.yellow, .orange], center: .center, startRadius: 0, endRadius: 15))
                    .frame(width: 30, height: 30)
                    .shadow(color: .yellow.opacity(0.5), radius: 8)
                    .position(x: ballX, y: ballY)
            }
            .onChange(of: r.accelX) { _, _ in
                guard let ax = r.accelX, let ay = r.accelY else { return }
                // Apply accelerometer as gravity
                ballVX += CGFloat(ax) * 2
                ballVY -= CGFloat(ay) * 2
                // Damping
                ballVX *= 0.95
                ballVY *= 0.95
                // Update position
                ballX += ballVX
                ballY += ballVY
                // Bounce off walls
                if ballX < 15 { ballX = 15; ballVX = abs(ballVX) * 0.7 }
                if ballX > w - 15 { ballX = w - 15; ballVX = -abs(ballVX) * 0.7 }
                if ballY < 15 { ballY = 15; ballVY = abs(ballVY) * 0.7 }
                if ballY > h - 15 { ballY = h - 15; ballVY = -abs(ballVY) * 0.7 }
            }
            .onAppear { ballX = w / 2; ballY = h / 2 }
        }
    }

    // MARK: - Shake Detection
    private func detectShake(r: MotionProvider.Reading) {
        guard let x = r.accelX, let y = r.accelY, let z = r.accelZ else { return }
        let mag = sqrt(x*x + y*y + z*z)
        if abs(mag - lastAccelMag) > 0.5 {
            if !shakeDetected {
                shakeDetected = true
                shakeCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shakeDetected = false }
            }
        }
        lastAccelMag = mag
    }

    // MARK: - Helpers
    private func axisGroup(_ title: String, x: Double, y: Double, z: Double, unit: String) -> some View {
        GroupBox(title) {
            HStack(spacing: 12) {
                axisBar("X", value: x, range: -2...2, color: .red)
                axisBar("Y", value: y, range: -2...2, color: .green)
                axisBar("Z", value: z, range: -2...2, color: .blue)
            }.padding(4)
            Text(unit).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func axisBar(_ label: String, value: Double, range: ClosedRange<Double>, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.2f", value)).font(.system(.caption, design: .monospaced, weight: .bold)).foregroundStyle(color)
            RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 12, height: 80)
                .overlay(alignment: .bottom) {
                    let pct = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: CGFloat(pct) * 80)
                }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func attitudeCircle(_ label: String, angle: Double, color: Color) -> some View {
        VStack {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 3).frame(width: 80, height: 80)
                Rectangle().fill(color.gradient).frame(width: 60, height: 4)
                    .rotationEffect(.degrees(angle * 180 / .pi))
                    .animation(.easeOut(duration: 0.1), value: angle)
            }
            Text(String(format: "%@: %.1f°", label, angle * 180 / .pi))
                .font(.system(.caption, design: .monospaced))
        }
    }
}
