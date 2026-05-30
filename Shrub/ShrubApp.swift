import SwiftUI
import SwiftData

@main
struct ShrubApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        .modelContainer(for: [Expense.self, ExpenseCategory.self])
    }
}
