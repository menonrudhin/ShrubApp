import SwiftUI

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

    @EnvironmentObject private var app: AppModel
    private let calendar = Calendar.current

    @State private var showLimitEditor = false
    @State private var limitText = ""

    private var expenses: [ExpenseItem] {
        app.expenses.filter { $0.category == category }
    }

    private var monthlyLimit: Double? { app.monthlyLimit(for: category) }
    private var isOverLimit: Bool { monthlyLimit.map { monthTotal > $0 } ?? false }

    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var currentMonth: Int { calendar.component(.month, from: .now) }

    private var monthExpenses: [ExpenseItem] {
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

                limitCard

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
        .alert("Monthly limit for \(category)", isPresented: $showLimitEditor) {
            TextField("Amount", text: $limitText)
                .keyboardType(.decimalPad)
            Button("Save", action: saveLimit)
            if monthlyLimit != nil {
                Button("Remove limit", role: .destructive) {
                    Task { await app.setMonthlyLimit(for: category, limit: nil) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This category turns red on the summary when this month's spending goes over the limit.")
        }
    }

    private var limitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monthly limit").font(.headline)
                Spacer()
                Button(monthlyLimit == nil ? "Set" : "Edit") {
                    limitText = monthlyLimit.map { String(format: "%.0f", $0) } ?? ""
                    showLimitEditor = true
                }
                .accessibilityIdentifier("editLimit")
            }

            if let limit = monthlyLimit {
                ProgressView(value: min(monthTotal, limit), total: limit)
                    .tint(isOverLimit ? .red : Theme.accent)
                HStack {
                    Text("\(monthTotal.asCurrency) of \(limit.asCurrency)")
                        .font(.caption)
                        .foregroundStyle(isOverLimit ? Color.red : .secondary)
                    Spacer()
                    if isOverLimit {
                        Text("Over by \((monthTotal - limit).asCurrency)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Text("No limit set. Add one to track overspending on \(category).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func saveLimit() {
        let cleaned = limitText.filter { $0.isNumber || $0 == "." }
        guard let value = Double(cleaned), value > 0 else { return }
        Task { await app.setMonthlyLimit(for: category, limit: value) }
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
