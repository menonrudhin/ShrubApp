import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @StateObject private var location = LocationManager()

    @FocusState private var amountFocused: Bool
    @State private var amountText = ""
    @State private var selectedCategory = ""
    @State private var showToast = false
    @State private var showAddCategory = false
    @State private var newCategoryName = ""

    @AppStorage("hasSeenSwipeHint") private var hasSeenSwipeHint = false
    @State private var showSwipeHint = false
    @State private var hintArrowShift = false

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

            swipeHintOverlay
        }
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = false }
        .onAppear {
            location.requestPermission()
            location.refresh()
            if selectedCategory.isEmpty {
                selectedCategory = app.categoryNames.first ?? ""
            }
            if !hasSeenSwipeHint {
                withAnimation(.easeInOut(duration: 0.4)) { showSwipeHint = true }
            }
        }
        .onChange(of: app.categoryNames) { _, names in
            if selectedCategory.isEmpty || !names.contains(selectedCategory) {
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
            groupMenu
        }
        .padding(.top, 12)
    }

    private var groupMenu: some View {
        Menu {
            Section(app.activeGroup?.name ?? "Group") {
                ForEach(app.groups) { group in
                    Button {
                        app.selectGroup(group.id)
                    } label: {
                        Label(group.name, systemImage: group.id == app.activeGroupId ? "checkmark" : "person.2")
                    }
                }
            }
            if let code = app.activeGroup?.inviteCode {
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy invite code (\(code))", systemImage: "doc.on.doc")
                }
            }
            Divider()
            Button { app.selectGroup(nil) } label: { Label("New / join group", systemImage: "plus") }
            Button(role: .destructive) { app.signOut() } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "person.2.fill").font(.caption)
                Text(app.activeGroup?.name ?? "Group")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("groupMenu")
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
            ForEach(app.categoryNames, id: \.self) { category in
                Button(category) { selectedCategory = category }
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

    @ViewBuilder
    private var swipeHintOverlay: some View {
        if showSwipeHint {
            ZStack {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture { dismissSwipeHint() }

                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.compact.left")
                            Image(systemName: "chevron.compact.left").opacity(0.55)
                            Image(systemName: "chevron.compact.left").opacity(0.25)
                        }
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .offset(x: hintArrowShift ? -14 : 10)

                        Text("Swipe left for your Summary")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Your charts and category breakdowns are one swipe away.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)

                        Button(action: dismissSwipeHint) {
                            Text("Got it")
                                .font(.headline)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 4)
                    }
                    .padding(28)
                    .background(Theme.cardBackground.opacity(0.92),
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityIdentifier("swipeHint")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .transition(.opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    hintArrowShift = true
                }
            }
        }
    }

    private func dismissSwipeHint() {
        hasSeenSwipeHint = true
        withAnimation(.easeInOut(duration: 0.3)) { showSwipeHint = false }
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
        let value = min(amount, maxAmount)
        let category = selectedCategory
        Task {
            await app.addExpense(
                category: category,
                amount: value,
                date: .now,
                locationName: location.locationName,
                latitude: location.latitude,
                longitude: location.longitude
            )
        }
        amountText = ""
        triggerToast()
        location.refresh()
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        newCategoryName = ""
        guard !name.isEmpty else { return }
        Task { await app.addCategory(name) }
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
