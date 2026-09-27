import XCTest

/// End-to-end on the iOS 27 simulator (iPhone or iPad) with the labelled simulated room: create space/room → scan →
/// place one asset per affinity → move/rotate/turn/undo → relaunch and recover committed state → counted delete.
/// Simulator evidence only; ARKit capture, occlusion and touch on real surfaces need a physical device (IE6.T2).
final class Kfn8iOSEndToEndTests: Kfn8UITestCase {
    func testBatchTwoFurniturePlaces() throws {
        placeBatchTwoFurniture(launch())
    }

    func testScanPlaceEditRelaunchDelete() throws {
        var app = launch()
        tap(app, "New space")
        tap(app, "New room")
        waitForText(app, containing: "Not scanned yet")
        tap(app, "Scan this room")
        waitForText(app, containing: "Aligned")
        waitForText(app, containing: "simulated room")

        for name in ["Ceramic vase", "Hanging industrial lamp", "Industrial wall sconce", "Modern arm chair"] {
            tap(app, "Add \(name)")
            XCTAssertTrue(placementRow(app, name).waitForExistence(timeout: 10), "\(name) was not placed")
        }
        XCTAssertFalse(app.staticTexts["There isn't enough space here"].exists)
        snapshot(app, "ios-four-affinities-placed")

        // Non-gesture edits on the chair, then undo one.
        let panelRow = app.descendants(matching: .any).matching(identifier: "room-panel-scroll").firstMatch.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Modern arm chair,")).firstMatch
        XCTAssertTrue(panelRow.waitForExistence(timeout: 10), "chair row not in the room panel")
        reveal(panelRow, in: app)
        if !panelRow.isSelected { panelRow.tap() }
        tap(app, "Right")
        tap(app, "Rotate left 15°")
        tap(app, "Undo")
        let redoEnabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.buttons["Redo"].firstMatch)
        wait(for: [redoEnabled], timeout: 10)

        // The on-screen turn button beside the chair goes through the same pipeline, so Undo reverses it too.
        let turn = app.buttons["Turn Modern arm chair 45 degrees"].firstMatch
        XCTAssertTrue(turn.waitForExistence(timeout: 10), "turn button beside the chair not shown")
        snapshot(app, "ios-turn-buttons")

        tap(app, "Leave room view")
        waitForText(app, containing: "Scanned")

        // Terminate and relaunch against the same store: committed state survives.
        app.terminate()
        app = launch()
        waitForText(app, containing: "Scanned")
        for name in ["Modern arm chair", "Industrial wall sconce", "Hanging industrial lamp", "Ceramic vase"] {
            XCTAssertTrue(placementRow(app, name).waitForExistence(timeout: 10), "\(name) missing after relaunch")
        }

        // Counted permanent delete of the room (from the sidebar; on iPhone go back to it first).
        let back = app.navigationBars.buttons.firstMatch
        if !app.buttons["Delete Room 1"].exists, back.exists { back.tap() }
        tap(app, "Delete Room 1")
        waitForText(app, containing: "Delete 1 room and 1 design? This can't be undone.")
        snapshot(app, "ios-counted-delete-confirmation")
        tap(app, "Delete permanently")
        // iPhone returns to the Spaces/Rooms list (iPad shows "No room yet" beside it); either way the room is gone.
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["Delete Room 1"].firstMatch)
        wait(for: [gone], timeout: 10)
    }
}
