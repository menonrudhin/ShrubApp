import SwiftUI
import SwiftData

/// Two horizontally paged screens: Home (page 0) and Summary (page 1).
/// Swipe left on Home -> Summary; swipe right on Summary -> Home.
struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.modelContext) private var context
    @Query private var localExpenses: [Expense]
    @State private var selection = 0

    private let migrationKey = "didMigrateLocalExpenses"

    var body: some View {
        Group {
            if app.user == nil {
                AuthView()
            } else if app.activeGroup == nil {
                GroupGateView()
            } else {
                pagedHome
            }
        }
        .task { seedLocalExpensesForUITestingIfRequested() }
        // Migrate any pre-cloud on-device expenses into the active group, once.
        .task(id: app.activeGroupId) { migrateLocalExpensesIfNeeded() }
    }

    /// Test hook: when launched with SEED_LOCAL_EXPENSES=1, plant a couple of
    /// on-device expenses (as if from before cloud sync) and reset the migration
    /// flag, so the UI test can verify migration into a freshly created group.
    private func seedLocalExpensesForUITestingIfRequested() {
        guard ProcessInfo.processInfo.environment["SEED_LOCAL_EXPENSES"] == "1" else { return }
        UserDefaults.standard.set(false, forKey: migrationKey)
        guard localExpenses.isEmpty else { return }
        context.insert(Expense(category: "Grocery", amount: 77, date: .now))
        context.insert(Expense(category: "Gas", amount: 33, date: .now))
        try? context.save()
    }

    private var pagedHome: some View {
        TabView(selection: $selection) {
            HomeView().tag(0)
            SummaryView().tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: selection) { _, _ in
            // Paging keeps both pages alive, so the amount field can stay
            // first responder after a swipe. Resign it whenever the page changes.
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func migrateLocalExpensesIfNeeded() {
        guard app.activeGroupId != nil,
              !UserDefaults.standard.bool(forKey: migrationKey),
              !localExpenses.isEmpty else { return }

        let payload = localExpenses.map {
            LocalExpense(category: $0.category, amount: $0.amount, date: $0.date,
                         locationName: $0.locationName, latitude: $0.latitude, longitude: $0.longitude)
        }
        Task {
            await app.importLocalExpenses(payload, createdByName: "Rudhin")
            if app.errorMessage == nil {
                // Mark done and clear the on-device copies now they live in the cloud.
                UserDefaults.standard.set(true, forKey: migrationKey)
                for expense in localExpenses { context.delete(expense) }
                try? context.save()
            }
        }
    }
}
