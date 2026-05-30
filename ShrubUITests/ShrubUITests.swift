import XCTest

final class ShrubUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Full interactive path: type amount -> save -> toast -> swipe to summary ->
    /// open a category -> swipe back home.
    func testExpenseEntryAndSummaryFlow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Shrub"].waitForExistence(timeout: 5), "Home should show app title")

        // Enter an amount in the currency field.
        let amountField = app.textFields["amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("42.50")
        XCTAssertEqual(amountField.value as? String, "42.50", "field should hold the typed amount")
        attach(app, "01-home-amount-entered")

        // Save and expect the fading toast.
        app.buttons["saveButton"].tap()
        XCTAssertTrue(app.staticTexts["saved expense"].waitForExistence(timeout: 3),
                      "'saved expense' toast should appear")
        attach(app, "02-saved-toast")

        // Field clears back to the placeholder after saving.
        XCTAssertEqual(amountField.value as? String, "0", "amount field should reset after save")

        // Swipe (page) left to the Summary screen.
        pageLeft(app)
        XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5), "Summary should appear after swipe")
        XCTAssertTrue(app.staticTexts["This Year"].exists)
        XCTAssertTrue(app.staticTexts["This Month"].exists)
        attach(app, "03-summary")

        // Scroll to the category table and open the Gas category we just spent on.
        let gasRow = app.staticTexts["category_Gas"]
        var scrolls = 0
        while !gasRow.isHittable && scrolls < 6 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(gasRow.isHittable, "Gas category row should be reachable")
        gasRow.tap()
        XCTAssertTrue(app.navigationBars["Gas"].waitForExistence(timeout: 5), "Category detail for Gas should open")
        attach(app, "04-category-detail")

        // Back to Summary, scroll to top, then page right home.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Summary"].waitForExistence(timeout: 5))
        app.swipeDown()
        app.swipeDown()
        pageRight(app)
        XCTAssertTrue(app.staticTexts["Shrub"].waitForExistence(timeout: 5), "Should return to Home after swipe right")
    }

    /// The currency field must clamp at $1,000,000.
    func testMaxAmountClamp() throws {
        let app = XCUIApplication()
        app.launch()
        let amountField = app.textFields["amountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("9999999")
        XCTAssertEqual(amountField.value as? String, "1000000", "amount should clamp to 1,000,000")
        attach(app, "05-clamped-amount")
    }

    // MARK: - Helpers

    /// Horizontal page swipe near the top, above the charts, to avoid chart gestures.
    private func pageLeft(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    private func pageRight(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.12))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.12))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
