import Foundation
import SwiftData

@Model
final class Expense {
    var category: String
    var amount: Double
    var date: Date
    var locationName: String?
    var latitude: Double?
    var longitude: Double?

    init(
        category: String,
        amount: Double,
        date: Date = .now,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.category = category
        self.amount = amount
        self.date = date
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
    }
}
