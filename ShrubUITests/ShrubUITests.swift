import XCTest

final class ShrubUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Cloud flow + shared categories: sign up -> create group -> the group is
    /// seeded with the shared default categories -> add a new shared category ->
    /// save an expense -> confirm it round-trips through Firestore on Summary.
    func testSharedCategoriesAndExpenseRoundTrip() throws {
        let app = makeApp()
        app.launch()
        let amount = signUpAndCreateGroup(app)

        // Shared categories were seeded for the new group.
        app.buttons["categoryMenu"].tap()
        XCTAssertTrue(app.buttons["Grocery"].waitForExistence(timeout: 10),
                      "new group should be seeded with shared default categories")

        // Add a new shared category; it should appear in the menu (via the listener).
        app.buttons["Add Category"].tap()
        let alert = app.alerts["New Category"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields.firstMatch.tap()
        alert.textFields.firstMatch.typeText("Brunch")
        alert.buttons["Add"].tap()

        app.buttons["categoryMenu"].tap()
        XCTAssertTrue(app.buttons["Brunch"].waitForExistence(timeout: 10),
                      "added shared category should appear from Firestore")
        app.buttons["Brunch"].tap()

        // Save an expense and confirm it round-trips onto Summary.
        amount.tap(); amount.typeText("25")
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.staticTexts["saved expense"].waitForExistence(timeout: 5))

        pageToSummary(app)
        XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(containsText(app, "25.00").waitForExistence(timeout: 15),
                      "the saved expense should round-trip back from Firestore")
    }

    /// Migration: with pre-cloud on-device expenses seeded, signing up and
    /// creating a group should import them into the group (so they appear on
    /// Summary). $77 Grocery + $33 Gas = $110 year total.
    func testLocalExpenseMigration() throws {
        let app = makeApp()
        app.launchEnvironment["SEED_LOCAL_EXPENSES"] = "1"
        app.launch()
        _ = signUpAndCreateGroup(app)

        pageToSummary(app)
        XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(containsText(app, "110.00").waitForExistence(timeout: 20),
                      "migrated local expenses ($77 + $33) should total $110 on Summary")
        XCTAssertTrue(containsText(app, "77.00").waitForExistence(timeout: 10),
                      "migrated Grocery expense should appear")
        // Recent-activity attribution shows the migrated expenses as "Rudhin".
        XCTAssertTrue(containsText(app, "Rudhin").waitForExistence(timeout: 10),
                      "recent activity should attribute migrated expenses to Rudhin")
    }

    /// First-run swipe tutorial: shows the "Swipe left for your Summary" coach
    /// mark on Home, and dismisses (and stays dismissed) after tapping "Got it".
    func testSwipeTutorialFirstRun() throws {
        let app = makeApp()
        app.launchEnvironment["SHOW_SWIPE_HINT"] = "1"
        app.launch()
        _ = signUpAndCreateGroup(app)

        XCTAssertTrue(app.staticTexts["Swipe left for your Summary"].waitForExistence(timeout: 10),
                      "first-run swipe tutorial should appear on Home")
        app.buttons["Got it"].tap()
        XCTAssertFalse(app.staticTexts["Swipe left for your Summary"].waitForExistence(timeout: 2),
                       "tutorial should dismiss after Got it")
    }

    /// Category monthly limit: with a $50 Grocery limit seeded and $77 of Grocery
    /// spend migrated in, the monthly summary should flag Grocery as over limit.
    func testCategoryOverMonthlyLimit() throws {
        let app = makeApp()
        app.launchEnvironment["SEED_LOCAL_EXPENSES"] = "1"           // Grocery $77, Gas $33
        app.launchEnvironment["SEED_CATEGORY_LIMIT"] = "Grocery:50"  // limit below spend
        app.launch()
        _ = signUpAndCreateGroup(app)

        pageToSummary(app)
        XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(containsText(app, "Over $50.00 limit").waitForExistence(timeout: 20),
                      "Grocery ($77) should be flagged over its $50 monthly limit")
    }

    // MARK: - Helpers

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1" // start signed out
        return app
    }

    /// Signs up a fresh account and creates a group; returns the amount field.
    @discardableResult
    private func signUpAndCreateGroup(_ app: XCUIApplication, groupName: String = "Family expenses") -> XCUIElement {
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

        let groupNameField = app.textFields["Group name (e.g. Family expenses)"]
        XCTAssertTrue(groupNameField.waitForExistence(timeout: 35), "should reach group gate after signup")
        // Let the auth -> group-gate transition / re-render burst settle so the
        // field can hold keyboard focus.
        Thread.sleep(forTimeInterval: 2)
        groupNameField.tap()
        groupNameField.typeText("\(groupName)\n")
        let createButton = app.buttons["Create"]
        XCTAssertTrue(createButton.waitUntilHittable(timeout: 10))
        createButton.tap()

        let amount = app.textFields["amountField"]
        XCTAssertTrue(amount.waitForExistence(timeout: 35), "should reach home after creating a group")
        return amount
    }

    private func pageToSummary(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    private func containsText(_ app: XCUIApplication, _ substring: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", substring)).firstMatch
    }
}

extension XCUIElement {
    /// Poll until the element is hittable (handles keyboard dismiss / transition timing).
    func waitUntilHittable(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isHittable { return true }
            usleep(200_000)
        }
        return isHittable
    }
}
