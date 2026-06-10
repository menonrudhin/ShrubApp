import XCTest

final class ShrubUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// End-to-end cloud flow: sign up -> create a shared group -> verify the
    /// amount clamp -> save an expense -> confirm it round-trips through
    /// Firestore and shows on the Summary screen.
    func testCloudSignupGroupAndExpenseRoundTrip() throws {
        let app = XCUIApplication()
        app.launch()

        // --- Sign up a fresh account ---
        XCTAssertTrue(app.staticTexts["Shrub"].waitForExistence(timeout: 10), "auth screen should appear")
        app.buttons["New here? Create an account"].tap()

        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Test User\n")

        let email = app.textFields["Email"]
        email.tap()
        email.typeText("test-\(UUID().uuidString.prefix(8))@shrub.test".lowercased() + "\n")

        let password = app.secureTextFields["Password (6+ characters)"]
        password.tap(); password.typeText("secret123\n")

        app.buttons["Sign Up"].tap()

        // --- Create a shared group ---
        let groupName = app.textFields["Group name (e.g. Family expenses)"]
        XCTAssertTrue(groupName.waitForExistence(timeout: 35), "should reach group gate after signup")
        groupName.tap(); groupName.typeText("Family expenses\n")
        app.buttons["Create"].tap()

        // --- Home screen reached (active group selected) ---
        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 35), "should reach home after creating a group")

        // Amount clamp still works.
        amount.tap(); amount.typeText("9999999")
        XCTAssertEqual(amount.value as? String, "1000000", "amount should clamp to 1,000,000")

        // Clear and enter a real expense.
        amount.tap()
        let current = (amount.value as? String) ?? ""
        if current != "0" {
            amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        amount.typeText("25")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.staticTexts["saved expense"].waitForExistence(timeout: 5), "save toast should show")

        // --- Swipe to Summary and confirm the Firestore expense appears ---
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5), "Summary should appear")

        let total = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "25.00")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 15),
                      "the $25 expense saved to Firestore should round-trip back and show on Summary")
    }
}
