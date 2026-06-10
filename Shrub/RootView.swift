import SwiftUI
import SwiftData

/// Two horizontally paged screens: Home (page 0) and Summary (page 1).
/// Swipe left on Home -> Summary; swipe right on Summary -> Home.
struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.modelContext) private var context
    @Query private var categories: [ExpenseCategory]
    @State private var selection = 0

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
        .task { seedCategoriesIfNeeded() }
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

    private func seedCategoriesIfNeeded() {
        guard categories.isEmpty else { return }
        for (index, name) in ExpenseCategory.defaults.enumerated() {
            context.insert(ExpenseCategory(name: name, sortOrder: index))
        }
        try? context.save()
    }
}
