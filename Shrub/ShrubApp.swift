import SwiftUI
import SwiftData
import FirebaseCore

@main
struct ShrubApp: App {
    @StateObject private var app = AppModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(Theme.accent)
                .task { app.start() }
        }
        .modelContainer(for: [Expense.self, ExpenseCategory.self])
    }
}
