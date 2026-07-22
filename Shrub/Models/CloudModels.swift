import Foundation

/// A signed-in user (mapped from FirebaseAuth + the users/{uid} doc).
struct AuthUser: Identifiable, Hashable {
    let id: String          // Firebase uid
    var displayName: String
    var email: String
}

/// A member of a shared expense group.
struct GroupMember: Hashable {
    let name: String
    let email: String
}

/// A shared expense group (the "Family expenses" concept). Stored at
/// groups/{id}; members write expenses into groups/{id}/expenses.
struct ExpenseGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let inviteCode: String
    let createdBy: String
    let memberIds: [String]
    let members: [String: GroupMember]

    func memberName(for uid: String) -> String {
        members[uid]?.name ?? "Member"
    }
}

/// A shared expense category within a group, with an optional monthly limit.
struct CategoryItem: Identifiable, Hashable {
    let id: String          // Firestore doc id
    let name: String
    let sortOrder: Int
    let monthlyLimit: Double?
}

/// A plain payload for migrating an on-device expense into a group.
struct LocalExpense {
    let category: String
    let amount: Double
    let date: Date
    let locationName: String?
    let latitude: Double?
    let longitude: Double?
}

/// One expense within a group, attributed to the member who entered it.
/// Plain value type the SwiftUI views compute over (mapped from Firestore).
struct ExpenseItem: Identifiable, Hashable {
    let id: String
    let category: String
    let amount: Double
    let date: Date
    let locationName: String?
    let createdBy: String       // uid
    let createdByName: String   // denormalized for display
}
