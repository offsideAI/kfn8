import XCTest

/// Simulator smoke test for the nonshipping probe: it launches, says plainly that world tracking needs a device, and
/// every page opens with its controls. The probe's real results only ever come from a physical iPhone or iPad.
final class ProbeSmokeTests: XCTestCase {
    @MainActor
    func testEveryPageOpensAndSimulatorIsLabelled() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let notSupported = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "World tracking isn't supported here")).firstMatch
        XCTAssertTrue(notSupported.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "SIMULATOR")).firstMatch.exists)

        let pages: [(String, String)] = [
            ("Find", "Place marker"), ("Collide", "Place box"), ("Occlude", "Room mesh occlusion"),
            ("Light", "Place lamp"), ("Photo", "Capture photo"), ("Evidence", "Records"), ("Setup", "Reset frame timing"),
        ]
        for (page, control) in pages {
            let tab = app.buttons[page].firstMatch
            tab.tap()
            // A busy simulator can drop a tap; one retry, then the page must be open.
            if !tab.wait(for: \.isSelected, toEqual: true, timeout: 5) { tab.tap() }
            XCTAssertTrue(tab.wait(for: \.isSelected, toEqual: true, timeout: 5), "\(page) page did not open")
            XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", control)).firstMatch
                .waitForExistence(timeout: 5), "\(page) page is missing \(control)")
        }

        // Without consent the capture button stays disabled.
        app.buttons["Photo"].firstMatch.tap()
        XCTAssertFalse(app.buttons["Capture photo"].isEnabled)
    }
}
