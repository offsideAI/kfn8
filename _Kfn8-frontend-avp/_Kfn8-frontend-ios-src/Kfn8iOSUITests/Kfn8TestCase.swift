import XCTest

/// Helpers for the iPhone and iPad end-to-end tests: an isolated store per test, tapping the way a person would (scroll
/// the panel until the control is on screen, then tap), text waits and the room set-up every test starts from.
/// Simulator evidence only.
@MainActor
class Kfn8TestCase: XCTestCase {
    var storePath: String!

    override func setUp() async throws {
        continueAfterFailure = false
        storePath = NSTemporaryDirectory() + "kfn8-ios-e2e-\(UUID().uuidString)"
    }

    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--store-path", storePath] + extra
        app.launch()
        return app
    }

    // MARK: Finding and tapping

    func button(_ app: XCUIApplication, _ label: String) -> XCUIElement { app.buttons[label].firstMatch }

    func tap(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let b = button(app, label)
        // Controls in lazily built grids only exist once scrolled into view, so look for them by scrolling too.
        if !b.waitForExistence(timeout: timeout) { reveal(app, b) }
        XCTAssertTrue(b.exists, "button '\(label)' not found", file: file, line: line)
        // Transient states (a sheet settling, a scroll decelerating) pass; only then scroll the panel.
        if !b.wait(for: \.isHittable, toEqual: true, timeout: 3) { reveal(app, b) }
        if b.isHittable {
            b.tap()
        } else {
            // On iPhone, while the room panel sheet is up, XCUITest's accessibility hit-test reports the room view's
            // top bar as unhittable although touches reach it (verified 2026-10-06: a coordinate tap on "Hide panel"
            // hid the panel). Tap where a finger would; every such tap is followed by checks on its effect.
            XCTAssertTrue(onScreen(app, b), "button '\(label)' can't be reached", file: file, line: line)
            b.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Scrolls the visible panel (room view sheet/column, or the room detail) until the element is on screen. Lazily
    /// built controls don't report a trustworthy position while scrolled away, so the panel is scrolled toward its top
    /// until the element appears or the screen stops changing (the top is reached), then toward its end the same way.
    /// Swipes are slow, so a sheet is never flung.
    func reveal(_ app: XCUIApplication, _ element: XCUIElement) {
        guard !(element.exists && element.isHittable), let scroller = scroller(app) else { return }
        for towardTop in [true, false] {
            var last = app.screenshot().pngRepresentation
            for _ in 0..<40 {
                if element.exists && element.isHittable { return }
                guard scroller.exists else { return }
                if towardTop { scroller.swipeDown(velocity: .slow) } else { scroller.swipeUp(velocity: .slow) }
                let now = app.screenshot().pngRepresentation
                if now == last { break } // reached this end of the panel
                last = now
            }
        }
    }

    /// Whether the element is drawn within the window, outside any scroll view (e.g. the room view's top bar).
    func onScreen(_ app: XCUIApplication, _ element: XCUIElement) -> Bool {
        element.exists && !element.frame.isEmpty && app.windows.firstMatch.frame.contains(element.frame)
    }

    private func scroller(_ app: XCUIApplication) -> XCUIElement? {
        for id in ["room-panel-scroll", "room-detail-scroll"] {
            let s = app.scrollViews[id].firstMatch
            if s.exists && s.isHittable { return s }
        }
        return nil
    }

    func text(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func waitForText(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(self.text(app, containing: text).waitForExistence(timeout: timeout), "text containing '\(text)' not found", file: file, line: line)
    }

    /// A placed item's row: "<name>, <dimensions>", with its position as the accessibility value.
    func row(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name + ",")).firstMatch
    }

    func position(_ app: XCUIApplication, _ name: String) -> String {
        let r = row(app, name)
        XCTAssertTrue(r.waitForExistence(timeout: 10), "row \(name) missing")
        return (r.value as? String) ?? ""
    }

    func selectRow(_ app: XCUIApplication, _ name: String) {
        let r = row(app, name)
        XCTAssertTrue(r.waitForExistence(timeout: 10), "row \(name) missing")
        reveal(app, r)
        if !r.isSelected { r.tap() } // rows toggle; a newly added item is already selected
    }

    func waitUntilEnabled(_ element: XCUIElement, _ enabled: Bool = true, timeout: TimeInterval = 10) -> Bool {
        element.wait(for: \.isEnabled, toEqual: enabled, timeout: timeout)
    }

    // MARK: Set-up

    /// New space and room, then the simulated scan in the room view until it reports Aligned.
    func scanNewRoom(_ app: XCUIApplication) {
        tap(app, "New space")
        tap(app, "New room")
        waitForText(app, containing: "Not scanned yet")
        tap(app, "Scan this room")
        waitForText(app, containing: "Aligned")
        waitForText(app, containing: "Simulated room (simulator only)")
    }

    func leaveRoomView(_ app: XCUIApplication) {
        tap(app, "Leave room view")
        XCTAssertTrue(button(app, "Leave room view").waitForNonExistence(timeout: 10))
    }

    /// On iPhone the room detail sits on top of the Spaces/Rooms list; go back to the list.
    func showSidebar(_ app: XCUIApplication) {
        if button(app, "New room").exists && button(app, "New room").isHittable { return }
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 3) { back.tap() }
    }

    func snapshot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
