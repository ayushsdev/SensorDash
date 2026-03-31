import SwiftUI
import Charts

struct TimeSample: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct SparklineChart: View {
    let title: String
    let samples: [TimeSample]
    let unit: String
    var color: Color = .blue
    var height: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = samples.last {
                    Text("\(String(format: "%.1f", last.value)) \(unit)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(color)
                }
            }

            if samples.count >= 2 {
                Chart(samples) { sample in
                    LineMark(
                        x: .value("Time", sample.date),
                        y: .value(title, sample.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", sample.date),
                        y: .value(title, sample.value)
                    )
                    .foregroundStyle(color.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: height)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: height)
                    .overlay {
                        Text("Collecting data...")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }
        }
    }
}

/// Thread-safe ring buffer for storing time-series sensor samples.
final class RingBuffer: @unchecked Sendable {
    private let capacity: Int
    private var storage: [TimeSample] = []
    private let lock = NSLock()

    init(capacity: Int = 300) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    func append(value: Double, date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        if storage.count >= capacity {
            storage.removeFirst()
        }
        storage.append(TimeSample(date: date, value: value))
    }

    var samples: [TimeSample] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll(keepingCapacity: true)
    }
}
