import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @StateObject private var location = LocationManager()

    @FocusState private var amountFocused: Bool
    @State private var amountText = ""
    @State private var selectedCategory = ""
    @State private var showToast = false
    @State private var showAddCategory = false
    @State private var newCategoryName = ""

    private let maxAmount: Double = 1_000_000

    private var amount: Double { Double(amountText) ?? 0 }
    private var canSave: Bool { amount > 0 }

    var body: some View {
        ZStack {
            Theme.primaryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                entryCard
                saveButton
                    .padding(.top, 24)
                locationHint
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)

            toast
        }
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = false }
        .onAppear {
            location.requestPermission()
            location.refresh()
            if selectedCategory.isEmpty {
                selectedCategory = categories.first?.name ?? "Grocery"
            }
        }
        .onChange(of: categories.map(\.name)) { _, names in
            if !names.contains(selectedCategory) {
                selectedCategory = names.first ?? ""
            }
        }
        .alert("New Category", isPresented: $showAddCategory) {
            TextField("Category name", text: $newCategoryName)
            Button("Add", action: addCategory)
            Button("Cancel", role: .cancel) { newCategoryName = "" }
        } message: {
            Text("Add a category to track a new kind of expense.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Theme.accent)
            Text("Shrub")
                .font(.title2.weight(.semibold))
            Spacer()
            Text(Date.now, format: .dateTime.month(.abbreviated).day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var entryCard: some View {
        VStack(spacing: 20) {
            categoryMenu
            amountField
        }
        .padding(24)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(categories) { category in
                Button(category.name) { selectedCategory = category.name }
            }
            Divider()
            Button {
                showAddCategory = true
            } label: {
                Label("Add Category", systemImage: "plus")
            }
        } label: {
            HStack {
                Text(selectedCategory.isEmpty ? "Select category" : selectedCategory)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.primaryBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityIdentifier("categoryMenu")
    }

    private var amountField: some View {
        HStack(spacing: 4) {
            Text("$")
                .font(.system(size: 44, weight: .light, design: .rounded))
                .foregroundStyle(.secondary)
            TextField("0", text: $amountText)
                .font(.system(size: 44, weight: .medium, design: .rounded))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.leading)
                .focused($amountFocused)
                .accessibilityIdentifier("amountField")
                .onChange(of: amountText) { _, newValue in
                    amountText = sanitize(newValue)
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save Expense")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Theme.accent : Color.gray.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
        }
        .disabled(!canSave)
        .accessibilityIdentifier("saveButton")
    }

    @ViewBuilder
    private var locationHint: some View {
        if let name = location.locationName {
            Label(name, systemImage: "location.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }

    private var toast: some View {
        VStack {
            Spacer()
            if showToast {
                Text("saved expense")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Theme.accent.opacity(0.95),
                                in: Capsule())
                    .accessibilityIdentifier("savedToast")
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 80)
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    /// Keep only digits and a single decimal point (max 2 places), clamp to $1M.
    private func sanitize(_ raw: String) -> String {
        var result = raw.filter { $0.isNumber || $0 == "." }
        if let dotIndex = result.firstIndex(of: ".") {
            let before = result[..<dotIndex]
            let afterDigits = result[result.index(after: dotIndex)...]
                .filter(\.isNumber)
                .prefix(2)
            result = String(before) + "." + String(afterDigits)
        }
        if let value = Double(result), value > maxAmount {
            result = String(format: "%.0f", maxAmount)
        }
        return result
    }

    private func save() {
        guard canSave else { return }
        let expense = Expense(
            category: selectedCategory,
            amount: min(amount, maxAmount),
            date: .now,
            locationName: location.locationName,
            latitude: location.latitude,
            longitude: location.longitude
        )
        context.insert(expense)
        try? context.save()

        amountText = ""
        triggerToast()
        location.refresh()
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        newCategoryName = ""
        guard !name.isEmpty, !categories.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        context.insert(ExpenseCategory(name: name, sortOrder: categories.count))
        try? context.save()
        selectedCategory = name
    }

    private func triggerToast() {
        withAnimation(.easeInOut(duration: 0.8)) { showToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeInOut(duration: 0.8)) { showToast = false }
        }
    }
}
