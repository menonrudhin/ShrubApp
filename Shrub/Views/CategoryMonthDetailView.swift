import SwiftUI
import SwiftData

/// Navigation route for a "By Category - This Month" row. A distinct type (vs a
/// bare String) lets the Summary screen send month taps here while year taps
/// still go to `CategoryDetailView`.
struct MonthlyCategoryRoute: Hashable {
    let category: String
}

/// Daily spend for one category within the current month: a line chart over the
/// days of the month plus a Date / Expense table of the days that had spending.
struct CategoryMonthDetailView: View {
    let category: String

    @Query private var expenses: [Expense]
    private let calendar = Calendar.current

    init(category: String) {
        self.category = category
        let predicate = #Predicate<Expense> { $0.category == category }
        _expenses = Query(filter: predicate, sort: \Expense.date)
    }

    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var currentMonth: Int { calendar.component(.month, from: .now) }

    private var monthExpenses: [Expense] {
        expenses.filter {
            calendar.component(.year, from: $0.date) == currentYear &&
            calendar.component(.month, from: $0.date) == currentMonth
        }
    }

    /// Total spend keyed by day-of-month.
    private var dailyTotals: [Int: Double] {
        var totals = [Int: Double]()
        for expense in monthExpenses {
            totals[calendar.component(.day, from: expense.date), default: 0] += expense.amount
        }
        return totals
    }

    /// One point per day of the month (zeros included) for a continuous line.
    private var dailyPoints: [ChartPoint] {
        let range = calendar.range(of: .day, in: .month, for: .now) ?? 1..<31
        let totals = dailyTotals
        return range.map { day in
            ChartPoint(x: day, label: "\(day)", value: totals[day] ?? 0)
        }
    }

    /// Table rows: only days that had spending, earliest first.
    private var tableRows: [(day: Int, total: Double)] {
        dailyTotals
            .filter { $0.value > 0 }
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, total: $0.value) }
    }

    private var monthTotal: Double {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var monthName: String {
        Date.now.formatted(.dateTime.month(.wide))
    }

    private func dateLabel(day: Int) -> String {
        var components = DateComponents()
        components.year = currentYear
        components.month = currentMonth
        components.day = day
        let date = calendar.date(from: components) ?? .now
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(monthName) total  \(monthTotal.asCurrency)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ExpenseLineChart(points: dailyPoints)
                    .frame(height: 240)
                    .padding(18)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                expenseTable
            }
            .padding(20)
        }
        .background(Theme.primaryBackground.ignoresSafeArea())
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var expenseTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date")
                Spacer()
                Text("Expense")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)

            Divider()

            if tableRows.isEmpty {
                Text("No expenses this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(tableRows.enumerated()), id: \.element.day) { index, row in
                    HStack {
                        Text(dateLabel(day: row.day))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(row.total.asCurrency)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 14)
                    if index < tableRows.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
