import SwiftUI

/// Minimal, eye-pleasing palette. Greens echo the "Shrub" name and read well
/// in both light and dark mode; backgrounds defer to the system so dark theme
/// is supported automatically.
enum Theme {
    static let accent = Color(red: 0.34, green: 0.71, blue: 0.49)   // soft leaf green
    static let highlight = Color(red: 0.95, green: 0.62, blue: 0.30) // warm amber for max points

    static var primaryBackground: Color { Color(.systemBackground) }
    static var cardBackground: Color { Color(.secondarySystemBackground) }
}

extension Double {
    /// "$1,234.56"
    var asCurrency: String {
        formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }

    /// Compact form for chart axes: "$1.2K", "$0".
    var asCompactCurrency: String {
        "$" + formatted(.number.notation(.compactName).precision(.fractionLength(0...1)).locale(Locale(identifier: "en_US")))
    }
}
