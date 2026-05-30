import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    @Attribute(.unique) var name: String
    var sortOrder: Int

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }

    /// Seeded on first launch; users can add more from the home screen.
    static let defaults = [
        "Gas", "Grocery", "Eat Out", "Utility Gas", "Utility Electricity",
        "Internet Bill", "Phone Bill", "Clothing", "Footwear", "Eyewear",
        "Haircut", "Skin Care", "Medicines", "Physician", "Learning"
    ]
}
