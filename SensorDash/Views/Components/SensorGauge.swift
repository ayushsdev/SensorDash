import SwiftUI

struct SensorGauge: View {
    let title: String
    let value: Double
    let min: Double
    let max: Double
    let unit: String
    var warningThreshold: Double? = nil
    var criticalThreshold: Double? = nil

    private var normalizedValue: Double {
        guard max > min else { return 0 }
        return (value - min) / (max - min)
    }

    private var gaugeColor: Color {
        if let critical = criticalThreshold, value >= critical { return .red }
        if let warning = warningThreshold, value >= warning { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 4) {
            Gauge(value: normalizedValue) {
                EmptyView()
            } currentValueLabel: {
                Text(formattedValue)
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(gaugeColor)
            } minimumValueLabel: {
                Text(formatNumber(min))
                    .font(.caption2)
            } maximumValueLabel: {
                Text(formatNumber(max))
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeColor)
            .scaleEffect(1.5)
            .frame(width: 80, height: 80)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var formattedValue: String {
        "\(formatNumber(value))\(unit)"
    }

    private func formatNumber(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 10000 {
            return String(format: "%.0f", n)
        }
        return String(format: "%.1f", n)
    }
}

struct SensorRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

struct SensorSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroupBox {
            content()
        } label: {
            Label(title, systemImage: icon)
                .font(.headline)
        }
    }
}
