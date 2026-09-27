import XCTest

/// Helpers shared by the visionOS and iPhone/iPad end-to-end UI tests: an isolated store per test, tapping the way a
/// person would (scroll into view, let the scroll settle), row selection, text waits and screenshots.
@MainActor
class Kfn8UITestCase: XCTestCase {
    var storePath: String!

    override func setUp() async throws {
        continueAfterFailure = false
        storePath = NSTemporaryDirectory() + "kfn8-e2e-\(UUID().uuidString)"
    }

    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--store-path", storePath] + extra
        app.launch()
        return app
    }

    func tap(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons[label].firstMatch.waitForExistence(timeout: timeout), "button '\(label)' not found", file: file, line: line)
        // Scroll it into view like a person would, let the scroll settle, then tap (never mid-scroll).
        var button = reachable(app, label)
        var swipes = 0
        while !button.isHittable && swipes < 12, let scroller = frontScroller(app) {
            if !isInPanel(button, app) && panel(app).exists {
                // Not drawn in the room panel yet (lazy grid): search it, first toward the top, then down.
                if swipes < 5 { scroller.swipeDown(velocity: .slow) } else { scroller.swipeUp(velocity: .slow) }
            } else if button.frame.midY < scroller.frame.minY {
                scroller.swipeDown(velocity: .slow) // scrolled past, above the visible area
            } else {
                scroller.swipeUp(velocity: .slow)   // below the visible area
            }
            swipes += 1
            button = reachable(app, label)
        }
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: button)
        wait(for: [hittable], timeout: timeout)
        Thread.sleep(forTimeInterval: 0.6)
        button.tap()
    }

    /// Scrolls the front panel until `element` is on screen (lazy grids only materialise controls that are visible).
    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.isHittable && swipes < 10, let scroller = frontScroller(app) {
            if element.frame.midY < scroller.frame.minY + 40 { scroller.swipeDown(velocity: .slow) } else { scroller.swipeUp(velocity: .slow) }
            swipes += 1
        }
    }

    /// The iPhone/iPad room view's scrollable panel (absent on visionOS and when the room view is closed).
    func panel(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "room-panel-scroll").firstMatch
    }

    func isInPanel(_ element: XCUIElement, _ app: XCUIApplication) -> Bool {
        let p = panel(app)
        return p.exists && p.buttons.matching(NSPredicate(format: "label == %@", element.label)).firstMatch.exists
    }

    /// The scrollable panel a person is looking at: the iPhone/iPad room view's panel when it is open (the main
    /// window stays in the accessibility tree underneath it), otherwise the main window's catalogue column.
    func frontScroller(_ app: XCUIApplication) -> XCUIElement? {
        let roomPanel = panel(app)
        if roomPanel.exists { return roomPanel }
        let scrollers = app.scrollViews.matching(identifier: "catalogue-scroll").allElementsBoundByIndex
        return scrollers.last(where: \.isHittable) ?? scrollers.last
    }

    /// The copy of a button a person can reach: already hittable, else the one inside the front panel.
    func reachable(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let byLabel = NSPredicate(format: "label == %@", label)
        let roomPanel = panel(app)
        if roomPanel.exists {
            let inPanel = roomPanel.buttons.matching(byLabel).firstMatch
            if inPanel.exists { return inPanel }
        }
        let copies = app.buttons.matching(byLabel).allElementsBoundByIndex
        if let hit = copies.first(where: \.isHittable) { return hit }
        return copies.last ?? app.buttons[label].firstMatch
    }

    /// Fixtures batch 2 (2026-09-26): each new floor piece can be added to a scanned room and appears in the Design.
    static let batchTwoFurniture = ["Tufted leather sofa", "Stone-top coffee table", "Oak side table", "Cube display shelves", "Leather ottoman"]

    func placeBatchTwoFurniture(_ app: XCUIApplication) {
        tap(app, "New space")
        tap(app, "New room")
        tap(app, "Scan this room")
        waitForText(app, containing: "Aligned")
        for name in Self.batchTwoFurniture {
            tap(app, "Add \(name)")
            XCTAssertTrue(placementRow(app, name).waitForExistence(timeout: 10), "\(name) was not placed")
        }
        snapshot(app, "batch-two-furniture-placed")
    }

    /// Placement rows are labelled "<name>, <dimensions>"; match by prefix.
    func tapRow(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "row '\(name)' not found", file: file, line: line)
        if !row.isSelected { row.tap() } // rows toggle; a newly added item is already selected
    }

    func placementRow(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    /// Captures both the main window and the whole app (on visionOS the latter shows the immersive layer).
    func snapshot(_ app: XCUIApplication, _ name: String) {
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

    func waitForText(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "text containing '\(text)' not found", file: file, line: line)
    }
}
