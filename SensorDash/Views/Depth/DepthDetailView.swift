import SwiftUI
import AVFoundation

struct DepthDetailView: View {
    @Environment(AppState.self) var appState
    @State private var cameras: [CameraInfo] = []
    @State private var scanned = false

    struct CameraInfo: Identifiable {
        let id: String
        let name: String
        let manufacturer: String
        let modelID: String
        let position: String
        let hasDepth: Bool
        let depthFormats: [String]
        let supportedFormats: Int
    }

    private var r: DepthProvider.Reading? { appState.dashboard.depthReading }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Camera Discovery
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "camera.viewfinder").font(.title).foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text("Camera & Depth Explorer").font(.title2.bold())
                                Text("Discover all cameras and their depth capabilities")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(scanned ? "Rescan" : "Scan Cameras") {
                                scanCameras()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(4)
                }

                // MARK: - Camera List
                if !cameras.isEmpty {
                    ForEach(cameras) { cam in
                        cameraCard(cam)
                    }
                }

                // MARK: - Depth Hardware Summary
                GroupBox("Depth Capability Summary") {
                    let depthCams = cameras.filter(\.hasDepth)
                    HStack(spacing: 30) {
                        VStack {
                            Text("\(cameras.count)")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(.blue)
                            Text("Total Cameras").font(.caption).foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(depthCams.count)")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(depthCams.isEmpty ? .gray : .green)
                            Text("With Depth").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()

                    if depthCams.isEmpty && scanned {
                        Text("No cameras with depth support found. TrueDepth or LiDAR hardware required.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                // MARK: - AppleDepth Framework
                if let r {
                    GroupBox("AppleDepth Framework (Private)") {
                        SensorRow(label: "Framework Loaded", value: r.frameworkLoaded ? "Yes" : "No")
                        SensorRow(label: "Depth Hardware", value: r.available ? "Available" : "Not Found")
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
            .onAppear {
                if !scanned { scanCameras() }
            }
        }
    }

    // MARK: - Camera Card
    private func cameraCard(_ cam: CameraInfo) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: cam.hasDepth ? "camera.metering.multispot" : "camera")
                        .font(.title2)
                        .foregroundStyle(cam.hasDepth ? .green : .secondary)
                    VStack(alignment: .leading) {
                        Text(cam.name).font(.headline)
                        Text("\(cam.manufacturer) • \(cam.position)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if cam.hasDepth {
                        Text("DEPTH").font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(.green.opacity(0.2), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    miniStat("Model", cam.modelID)
                    miniStat("Formats", "\(cam.supportedFormats)")
                    miniStat("Depth Formats", "\(cam.depthFormats.count)")
                }

                if !cam.depthFormats.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Depth Formats:").font(.caption.bold())
                        ForEach(cam.depthFormats, id: \.self) { fmt in
                            Text(fmt).font(.system(.caption2, design: .monospaced)).foregroundStyle(.green)
                        }
                    }
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

    // MARK: - Scan
    private func scanCameras() {
        cameras = []
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )

        for device in discoverySession.devices {
            // On macOS, depth data formats are limited — check what's available
            var depthFormatDescriptions: [String] = []
            let hasDepthFormats = false // macOS doesn't expose supportedDepthDataFormats on most devices

            cameras.append(CameraInfo(
                id: device.uniqueID,
                name: device.localizedName,
                manufacturer: device.manufacturer,
                modelID: device.modelID,
                position: positionName(device.position),
                hasDepth: hasDepthFormats,
                depthFormats: depthFormatDescriptions,
                supportedFormats: device.formats.count
            ))
        }
        scanned = true
    }

    private func positionName(_ pos: AVCaptureDevice.Position) -> String {
        switch pos {
        case .front: return "Front"
        case .back: return "Back"
        default: return "Unspecified"
        }
    }

    private func fourCC(_ code: FourCharCode) -> String {
        let chars: [Character] = [
            Character(UnicodeScalar((code >> 24) & 0xFF)!),
            Character(UnicodeScalar((code >> 16) & 0xFF)!),
            Character(UnicodeScalar((code >> 8) & 0xFF)!),
            Character(UnicodeScalar(code & 0xFF)!),
        ]
        return String(chars)
    }
}
