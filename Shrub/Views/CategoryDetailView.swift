import SwiftUI

struct CategoryDetailView: View {
    let category: String

    @EnvironmentObject private var app: AppModel
    private let calendar = Calendar.current

    private var expenses: [ExpenseItem] {
        app.expenses.filter { $0.category == category }
    }

    private var currentYear: Int { calendar.component(.year, from: .now) }

    private var monthlyPoints: [ChartPoint] {
        var totals = [Int: Double]()
        for expense in expenses where calendar.component(.year, from: expense.date) == currentYear {
            totals[calendar.component(.month, from: expense.date), default: 0] += expense.amount
        }
        return (1...12).map { month in
            ChartPoint(x: month, label: SummaryView.monthAbbreviations[month - 1], value: totals[month] ?? 0)
        }
    }

    private var yearTotal: Double {
        monthlyPoints.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(String(currentYear)) total  \(yearTotal.asCurrency)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ExpenseLineChart(points: monthlyPoints)
                    .frame(height: 240)
                    .padding(18)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(20)
        }
        .background(Theme.primaryBackground.ignoresSafeArea())
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
    }
}
