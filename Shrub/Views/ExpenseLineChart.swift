import SwiftUI
import Charts

struct ChartPoint: Identifiable {
    let id = UUID()
    let x: Int        // month (1-12), day (1-31), etc.
    let label: String // axis label
    let value: Double
}

/// A line chart that highlights the maximum point by default and lets the user
/// tap/drag to highlight any point. Shared by the year, month, and category views.
struct ExpenseLineChart: View {
    let points: [ChartPoint]
    var accent: Color = Theme.accent

    @State private var selectedX: Int?

    private var maxPoint: ChartPoint? {
        points.filter { $0.value > 0 }.max { $0.value < $1.value }
    }

    private var activePoint: ChartPoint? {
        if let selectedX, let match = points.first(where: { $0.x == selectedX }) {
            return match
        }
        return maxPoint
    }

    /// Thin out x-axis labels so dense charts (days of month) stay readable.
    private var axisValues: [Int] {
        guard points.count > 12 else { return points.map(\.x) }
        let step = max(1, points.count / 8)
        return points.enumerated().filter { $0.offset % step == 0 }.map { $0.element.x }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("x", point.x),
                    y: .value("Amount", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent.opacity(0.28), accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("x", point.x),
                    y: .value("Amount", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            if let maxPoint, maxPoint.value > 0 {
                PointMark(
                    x: .value("x", maxPoint.x),
                    y: .value("Amount", maxPoint.value)
                )
                .foregroundStyle(Theme.highlight)
                .symbolSize(70)
            }

            if let activePoint {
                RuleMark(x: .value("x", activePoint.x))
                    .foregroundStyle(Color.gray.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("x", activePoint.x),
                    y: .value("Amount", activePoint.value)
                )
                .foregroundStyle(accent)
                .symbolSize(50)
                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    VStack(spacing: 2) {
                        Text(activePoint.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(activePoint.value.asCurrency)
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .chartXSelection(value: $selectedX)
        .chartXAxis {
            AxisMarks(values: axisValues) { value in
                if let x = value.as(Int.self),
                   let point = points.first(where: { $0.x == x }) {
                    AxisGridLine()
                    AxisValueLabel { Text(point.label) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                if let amount = value.as(Double.self) {
                    AxisValueLabel { Text(amount.asCompactCurrency) }
                }
            }
        }
    }
}
