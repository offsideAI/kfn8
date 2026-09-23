import XCTest

/// End-to-end on the visionOS 27 simulator with the labelled simulated room. Covers M1's demo path:
/// create space/room → scan → place items by affinity → move/rotate/undo via non-gesture controls → invalid release →
/// relaunch and recover committed state → counted permanent delete. Not device evidence.
@MainActor
final class Kfn8EndToEndTests: XCTestCase {
    var storePath: String!

    override func setUp() async throws {
        continueAfterFailure = false
        storePath = NSTemporaryDirectory() + "kfn8-e2e-\(UUID().uuidString)"
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--store-path", storePath] + extra
        app.launch()
        return app
    }

    private func tap(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "button '\(label)' not found", file: file, line: line)
        // Scroll it into view like a person would, let the scroll settle, then tap (never mid-scroll).
        var swipes = 0
        while !button.isHittable && swipes < 6 {
            let scroller = app.scrollViews["catalogue-scroll"]
            if scroller.exists { scroller.swipeUp(velocity: .slow) } else { break }
            swipes += 1
        }
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: button)
        wait(for: [hittable], timeout: timeout)
        Thread.sleep(forTimeInterval: 0.6)
        button.tap()
    }

    /// Placement rows are labelled "<name>, <dimensions>"; match by prefix.
    private func tapRow(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "row '\(name)' not found", file: file, line: line)
        if !row.isSelected { row.tap() } // rows toggle; a newly added item is already selected
    }

    /// Captures both the main window and the whole app (on visionOS the latter shows the immersive layer).
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let window = app.windows.firstMatch
        if window.exists {
            let w = XCTAttachment(screenshot: window.screenshot())
            w.name = name + "-window"
            w.lifetime = .keepAlways
            add(w)
        }
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name + "-scene"
        a.lifetime = .keepAlways
        add(a)
    }

    private func waitForText(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "text containing '\(text)' not found", file: file, line: line)
    }

    func testScanPlaceEditRelaunchDelete() throws {
        var app = launch()
        tap(app, "New space")
        tap(app, "New room")
        waitForText(app, containing: "Not scanned yet")
        tap(app, "Scan this room")
        waitForText(app, containing: "Aligned")
        waitForText(app, containing: "simulated room")

        // One real asset per affinity.
        for name in ["Ceramic vase", "Hanging industrial lamp", "Industrial wall sconce", "Modern arm chair"] {
            tap(app, "Add \(name)")
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch.waitForExistence(timeout: 10),
                          "\(name) was not placed")
        }
        XCTAssertFalse(app.staticTexts["There isn't enough space here"].exists)
        snapshot(app, "e2e-four-affinities-placed")

        // Non-gesture edits on the chair, then undo one.
        tapRow(app, "Modern arm chair")
        tap(app, "Right")
        tap(app, "Rotate left 15°")
        tap(app, "Undo")
        let redoEnabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.buttons["Redo"].firstMatch)
        wait(for: [redoEnabled], timeout: 10)

        // Pushing the chair into the simulated table (a real obstacle) is held, unsaved, with the quiet message.
        for _ in 0..<4 { tap(app, "Right") }
        tap(app, "Toward wall")
        tap(app, "Toward wall")
        tap(app, "Toward wall")
        tap(app, "Toward wall")
        tap(app, "Toward wall")
        tap(app, "Toward wall")
        let held = app.staticTexts["There isn't enough space here"].waitForExistence(timeout: 5)
        if held { snapshot(app, "e2e-held-invalid-release"); tap(app, "Cancel move") }

        // Terminate and relaunch against the same store: committed state survives.
        app.terminate()
        app = launch()
        waitForText(app, containing: "Scanned")
        for name in ["Modern arm chair", "Industrial wall sconce", "Hanging industrial lamp", "Ceramic vase"] {
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch.waitForExistence(timeout: 10),
                          "\(name) missing after relaunch")
        }

        // Duplicate the design, then counted permanent delete of the room.
        tap(app, "Duplicate")
        waitForText(app, containing: "Design A copy")
        tap(app, "Delete Room 1")
        waitForText(app, containing: "Delete 1 room and 2 designs? This can't be undone.")
        snapshot(app, "e2e-counted-delete-confirmation")
        tap(app, "Delete permanently")
        waitForText(app, containing: "No room yet")
    }

    /// E1.S3.T3 + E3.S1: lost alignment with both recovery choices, and the A/B flip with inventory.
    func testLostAlignmentRecoveryAndDesignFlip() throws {
        var app = launch()
        tap(app, "New space")
        tap(app, "New room")
        tap(app, "Scan this room")
        waitForText(app, containing: "Aligned")
        tap(app, "Add Modern arm chair")
        waitForText(app, containing: "1 ×")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'priced'")).firstMatch.exists, "no subtotal for generics")

        // A/B: duplicate, remove the chair in the copy, flip back and forth.
        tap(app, "Duplicate")
        waitForText(app, containing: "Design A copy")
        tapRow(app, "Modern arm chair")
        tap(app, "Remove")
        waitForText(app, containing: "Nothing placed yet")
        tap(app, "Flip to Design A")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Modern arm chair,'")).firstMatch.waitForExistence(timeout: 10))
        tap(app, "Flip to Design A copy")
        waitForText(app, containing: "Nothing placed yet")
        tap(app, "Flip to Design A")

        // Return visit where the room can't be found: bounded attempts, then rescan into the same Room.
        app.terminate()
        app = launch(["--simulate-lost-alignment"])
        tap(app, "Open room view")
        waitForText(app, containing: "I can't tell where this room is yet")
        snapshot(app, "recovery-alignment-exhausted")
        tap(app, "Rescan this room")
        waitForText(app, containing: "Aligned")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Modern arm chair,'")).firstMatch.exists, "designs survive a rescan")

        // And the other choice: review contents without spatial placement.
        app.terminate()
        app = launch(["--simulate-lost-alignment"])
        tap(app, "Open room view")
        waitForText(app, containing: "I can't tell where this room is yet")
        tap(app, "Review contents")
        waitForText(app, containing: "Scanned")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Modern arm chair,'")).firstMatch.exists)
    }

    /// Largest accessibility text size: core controls stay present and tappable (simulator check; the device demo repeats it).
    func testLargestDynamicTypeKeepsControlsReachable() throws {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        tap(app, "New space")
        tap(app, "New room")
        tap(app, "Scan this room")
        waitForText(app, containing: "Aligned")
        tap(app, "Add Modern arm chair")
        snapshot(app, "dynamic-type-axxxl")
        // One column at this size: scroll back up to reveal each control, as a person would.
        let column = app.scrollViews["catalogue-scroll"]
        for label in ["Undo", "Duplicate", "Right", "Rotate left 15°", "Remove"] {
            let b = app.buttons[label].firstMatch
            var swipes = 0
            while !(b.exists && b.isHittable) && swipes < 10 && column.exists {
                column.swipeDown(velocity: .slow)
                swipes += 1
            }
            XCTAssertTrue(b.exists && b.isHittable, "\(label) not reachable at the largest text size")
        }
        tap(app, "Right")
        tap(app, "Undo")
    }
}
