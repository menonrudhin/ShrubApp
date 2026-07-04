import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Central app state backed by Firebase: authentication, the user's expense
/// groups, the active group, and that group's expenses (live via listeners).
@MainActor
final class AppModel: ObservableObject {
    @Published var user: AuthUser?
    @Published var groups: [ExpenseGroup] = []
    @Published var activeGroupId: String?
    @Published var expenses: [ExpenseItem] = []
    @Published var categories: [String] = []
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var groupsListener: ListenerRegistration?
    private var expensesListener: ListenerRegistration?
    private var categoriesListener: ListenerRegistration?

    private let activeGroupKey = "activeGroupId"

    var activeGroup: ExpenseGroup? {
        groups.first { $0.id == activeGroupId }
    }

    // MARK: - Lifecycle

    func start() {
        if ProcessInfo.processInfo.environment["UITEST_RESET"] == "1" {
            try? Auth.auth().signOut()
            UserDefaults.standard.removeObject(forKey: activeGroupKey)
            // Suppress the first-run swipe tutorial in tests unless explicitly requested.
            let showHint = ProcessInfo.processInfo.environment["SHOW_SWIPE_HINT"] == "1"
            UserDefaults.standard.set(!showHint, forKey: "hasSeenSwipeHint")
        }
        activeGroupId = UserDefaults.standard.string(forKey: activeGroupKey)
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, fbUser in
            guard let self else { return }
            if let fbUser {
                self.user = AuthUser(
                    id: fbUser.uid,
                    displayName: fbUser.displayName ?? "Member",
                    email: fbUser.email ?? ""
                )
                self.observeGroups()
            } else {
                self.user = nil
                self.teardownData()
            }
        }
    }

    private func teardownData() {
        groupsListener?.remove(); groupsListener = nil
        expensesListener?.remove(); expensesListener = nil
        categoriesListener?.remove(); categoriesListener = nil
        groups = []
        expenses = []
        categories = []
    }

    // MARK: - Authentication

    func signUp(name: String, email: String, password: String) async {
        await run {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try await change.commitChanges()
            try await self.db.collection("users").document(result.user.uid).setData([
                "displayName": name,
                "email": email
            ])
            self.user = AuthUser(id: result.user.uid, displayName: name, email: email)
        }
    }

    func signIn(email: String, password: String) async {
        await run {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        activeGroupId = nil
        UserDefaults.standard.removeObject(forKey: activeGroupKey)
    }

    // MARK: - Groups

    private func observeGroups() {
        guard let uid = user?.id else { return }
        groupsListener?.remove()
        groupsListener = db.collection("groups")
            .whereField("memberIds", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.groups = (snapshot?.documents ?? []).compactMap(Self.group(from:))
                // Default to the first group if none selected, or if the
                // selected one is no longer accessible.
                if self.activeGroupId == nil || !self.groups.contains(where: { $0.id == self.activeGroupId }) {
                    self.selectGroup(self.groups.first?.id)
                } else {
                    self.attachActiveGroupListeners()
                }
            }
    }

    func selectGroup(_ id: String?) {
        activeGroupId = id
        if let id {
            UserDefaults.standard.set(id, forKey: activeGroupKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeGroupKey)
        }
        attachActiveGroupListeners()
    }

    private func attachActiveGroupListeners() {
        observeExpenses()
        observeCategories()
    }

    func createGroup(name: String) async {
        guard let user else { return }
        await run {
            let code = Self.makeInviteCode()
            let ref = self.db.collection("groups").document()
            try await ref.setData([
                "name": name,
                "inviteCode": code,
                "createdBy": user.id,
                "memberIds": [user.id],
                "members": [user.id: ["name": user.displayName, "email": user.email]]
            ])
            // Seed the shared default categories for the new group.
            let batch = self.db.batch()
            for (index, categoryName) in ExpenseCategory.defaults.enumerated() {
                let catRef = ref.collection("categories").document()
                batch.setData(["name": categoryName, "sortOrder": index], forDocument: catRef)
            }
            try await batch.commit()
            self.selectGroup(ref.documentID)
        }
    }

    func joinGroup(code: String) async {
        guard let user else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        await run {
            let query = try await self.db.collection("groups")
                .whereField("inviteCode", isEqualTo: trimmed)
                .limit(to: 1)
                .getDocuments()
            guard let doc = query.documents.first else {
                throw AppError.message("No group found for code \(trimmed).")
            }
            try await doc.reference.updateData([
                "memberIds": FieldValue.arrayUnion([user.id]),
                "members.\(user.id)": ["name": user.displayName, "email": user.email]
            ])
            self.selectGroup(doc.documentID)
        }
    }

    // MARK: - Expenses

    private func observeExpenses() {
        expensesListener?.remove()
        expenses = []
        guard let groupId = activeGroupId else { return }
        expensesListener = db.collection("groups").document(groupId)
            .collection("expenses")
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.expenses = (snapshot?.documents ?? []).compactMap(Self.expense(from:))
            }
    }

    func addExpense(category: String, amount: Double, date: Date,
                    locationName: String?, latitude: Double?, longitude: Double?) async {
        guard let user, let groupId = activeGroupId else { return }
        await run {
            var data: [String: Any] = [
                "category": category,
                "amount": amount,
                "date": Timestamp(date: date),
                "createdBy": user.id,
                "createdByName": user.displayName
            ]
            data["locationName"] = locationName
            data["latitude"] = latitude
            data["longitude"] = longitude
            try await self.db.collection("groups").document(groupId)
                .collection("expenses").addDocument(data: data)
        }
    }

    /// Bulk-import on-device expenses into the active group (one-time migration).
    func importLocalExpenses(_ items: [LocalExpense], createdByName name: String) async {
        guard let user, let groupId = activeGroupId, !items.isEmpty else { return }
        await run {
            let batch = self.db.batch()
            let coll = self.db.collection("groups").document(groupId).collection("expenses")
            for item in items {
                var data: [String: Any] = [
                    "category": item.category,
                    "amount": item.amount,
                    "date": Timestamp(date: item.date),
                    "createdBy": user.id,
                    "createdByName": name
                ]
                data["locationName"] = item.locationName
                data["latitude"] = item.latitude
                data["longitude"] = item.longitude
                batch.setData(data, forDocument: coll.document())
            }
            try await batch.commit()
        }
    }

    // MARK: - Categories (shared per group)

    private func observeCategories() {
        categoriesListener?.remove()
        categories = []
        guard let groupId = activeGroupId else { return }
        categoriesListener = db.collection("groups").document(groupId)
            .collection("categories")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.categories = (snapshot?.documents ?? [])
                    .compactMap { $0.data()["name"] as? String }
            }
    }

    func addCategory(_ name: String) async {
        guard let groupId = activeGroupId else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !categories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        let order = categories.count
        await run {
            try await self.db.collection("groups").document(groupId)
                .collection("categories")
                .addDocument(data: ["name": trimmed, "sortOrder": order])
        }
    }

    // MARK: - Helpers

    private func run(_ work: @escaping () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        do {
            try await work()
        } catch {
            errorMessage = (error as? AppError)?.text ?? error.localizedDescription
        }
        isWorking = false
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // no ambiguous chars
        let body = (0..<5).map { _ in alphabet.randomElement()! }
        return "FAM-" + String(body)
    }

    private static func group(from doc: QueryDocumentSnapshot) -> ExpenseGroup? {
        let d = doc.data()
        guard let name = d["name"] as? String,
              let code = d["inviteCode"] as? String,
              let createdBy = d["createdBy"] as? String,
              let memberIds = d["memberIds"] as? [String] else { return nil }
        var members: [String: GroupMember] = [:]
        if let raw = d["members"] as? [String: [String: String]] {
            for (uid, info) in raw {
                members[uid] = GroupMember(name: info["name"] ?? "Member", email: info["email"] ?? "")
            }
        }
        return ExpenseGroup(id: doc.documentID, name: name, inviteCode: code,
                            createdBy: createdBy, memberIds: memberIds, members: members)
    }

    private static func expense(from doc: QueryDocumentSnapshot) -> ExpenseItem? {
        let d = doc.data()
        guard let category = d["category"] as? String,
              let amount = d["amount"] as? Double,
              let ts = d["date"] as? Timestamp else { return nil }
        return ExpenseItem(
            id: doc.documentID,
            category: category,
            amount: amount,
            date: ts.dateValue(),
            locationName: d["locationName"] as? String,
            createdBy: d["createdBy"] as? String ?? "",
            createdByName: d["createdByName"] as? String ?? "Member"
        )
    }
}

enum AppError: Error {
    case message(String)
    var text: String { if case let .message(m) = self { return m }; return "Something went wrong." }
}
