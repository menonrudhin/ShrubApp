import SwiftUI
import SwiftData

/// Two horizontally paged screens: Home (page 0) and Summary (page 1).
/// Swipe left on Home -> Summary; swipe right on Summary -> Home.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var categories: [ExpenseCategory]
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView().tag(0)
            SummaryView().tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task { seedCategoriesIfNeeded() }
    }

    private func seedCategoriesIfNeeded() {
        guard categories.isEmpty else { return }
        for (index, name) in ExpenseCategory.defaults.enumerated() {
            context.insert(ExpenseCategory(name: name, sortOrder: index))
        }
        try? context.save()
    }
}
