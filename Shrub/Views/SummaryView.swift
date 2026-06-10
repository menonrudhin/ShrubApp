import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var app: AppModel

    private var expenses: [ExpenseItem] { app.expenses }

    private let calendar = Calendar.current

    private var currentYear: Int { calendar.component(.year, from: .now) }
    private var currentMonth: Int { calendar.component(.month, from: .now) }

    private var yearExpenses: [ExpenseItem] {
        expenses.filter { calendar.component(.year, from: $0.date) == currentYear }
    }

    // Year: total per month (Jan–Dec).
    private var monthlyPoints: [ChartPoint] {
        var totals = [Int: Double]()
        for expense in yearExpenses {
            totals[calendar.component(.month, from: expense.date), default: 0] += expense.amount
        }
        return (1...12).map { month in
            ChartPoint(x: month, label: Self.monthAbbreviations[month - 1], value: totals[month] ?? 0)
        }
    }

    // Month: total per day of the current month.
    private var dailyPoints: [ChartPoint] {
        let range = calendar.range(of: .day, in: .month, for: .now) ?? 1..<31
        var totals = [Int: Double]()
        for expense in yearExpenses where calendar.component(.month, from: expense.date) == currentMonth {
            totals[calendar.component(.day, from: expense.date), default: 0] += expense.amount
        }
        return range.map { day in
            ChartPoint(x: day, label: "\(day)", value: totals[day] ?? 0)
        }
    }

    private var categoryTotalsYearly: [(name: String, total: Double)] {
        var totals = [String: Double]()
        for expense in yearExpenses {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    
    private var categoryTotalsMonthly: [(name: String, total: Double)] {
        var totals = [String: Double]()
        for expense in yearExpenses where calendar.component(.month, from: expense.date) == currentMonth {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var yearTotal: Double {
        yearExpenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    summaryHeader

                    chartCard(
                        title: "This Year",
                        subtitle: "Monthly spend in \(String(currentYear))",
                        points: monthlyPoints
                    )

                    chartCard(
                        title: "This Month",
                        subtitle: Date.now.formatted(.dateTime.month(.wide)),
                        points: dailyPoints
                    )

                    categorySectionMonthly
                    
                    categorySectionYearly
                }
                .padding(20)
            }
            .background(Theme.primaryBackground.ignoresSafeArea())
            .navigationDestination(for: String.self) { category in
                CategoryDetailView(category: category)
            }
            .navigationDestination(for: MonthlyCategoryRoute.self) { route in
                CategoryMonthDetailView(category: route.category)
            }
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Summary")
                .font(.title2.weight(.semibold))
            Text("\(String(currentYear)) total  \(yearTotal.asCurrency)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func chartCard(title: String, subtitle: String, points: [ChartPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            ExpenseLineChart(points: points)
                .frame(height: 200)
        }
        .padding(18)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var categorySectionYearly: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category - This Year")
                .font(.headline)

            if categoryTotalsYearly.isEmpty {
                Text("No expenses yet. Add one from the home screen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(categoryTotalsYearly.enumerated()), id: \.element.name) { index, row in
                        NavigationLink(value: row.name) {
                            HStack {
                                Text(row.name)
                                    .foregroundStyle(.primary)
                                    .accessibilityIdentifier("category_\(row.name)")
                                Spacer()
                                Text(row.total.asCurrency)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 14)
                        }
                        if index < categoryTotalsYearly.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
    
    private var categorySectionMonthly: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category - This Month")
                .font(.headline)

            if categoryTotalsMonthly.isEmpty {
                Text("No expenses yet. Add one from the home screen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(categoryTotalsMonthly.enumerated()), id: \.element.name) { index, row in
                        NavigationLink(value: MonthlyCategoryRoute(category: row.name)) {
                            HStack {
                                Text(row.name)
                                    .foregroundStyle(.primary)
                                    .accessibilityIdentifier("monthCategory_\(row.name)")
                                Spacer()
                                Text(row.total.asCurrency)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 14)
                        }
                        if index < categoryTotalsMonthly.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    static let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}
