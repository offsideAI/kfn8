import XCTest

/// I1.S6.T1 on the iPhone and iPad simulators with the labelled simulated room: scan, place one real fixture per
/// affinity, edit with buttons, the on-screen turn button and touch, relaunch, duplicate and delete. Not device evidence.
final class RoomEndToEndTests: Kfn8TestCase {
    static let fourAffinities = ["Ceramic vase", "Hanging industrial lamp", "Industrial wall sconce", "Modern arm chair"]

    func testScanPlaceEditRelaunchDelete() throws {
        var app = launch()
        scanNewRoom(app)

        for name in Self.fourAffinities {
            tap(app, "Add \(name)")
            XCTAssertTrue(row(app, name).waitForExistence(timeout: 15), "\(name) was not placed")
        }
        XCTAssertFalse(text(app, containing: "There isn't enough space here").exists)
        // The pendant and the sconce are the two virtual lights; they can be switched off and on.
        let lamps = app.switches["Lamps on"].firstMatch
        XCTAssertTrue(lamps.waitForExistence(timeout: 5), "no lamp switch with two lighting fixtures placed")
        snapshot(app, "four-affinities-placed")

        // Buttons move and turn the chair, and the saved position changes accordingly.
        selectRow(app, "Modern arm chair")
        let start = position(app, "Modern arm chair")
        tap(app, "Right")
        let movedRight = position(app, "Modern arm chair")
        XCTAssertNotEqual(movedRight, start, "Right didn't move the chair")
        tap(app, "Rotate left 15°")
        XCTAssertTrue(position(app, "Modern arm chair").contains("turned 15°") || position(app, "Modern arm chair") != movedRight)
        tap(app, "Undo")
        XCTAssertEqual(position(app, "Modern arm chair"), movedRight, "Undo didn't restore the turn")
        XCTAssertTrue(waitUntilEnabled(button(app, "Redo")))

        // Hide the panel, as a person would, to reach the item behind it. The on-screen turn button turns the chair
        // 45° clockwise (a saved edit, so the Redo history is cleared).
        tap(app, "Hide panel")
        let turn = button(app, "Turn Modern arm chair 45 degrees")
        XCTAssertTrue(turn.waitForExistence(timeout: 10), "no on-screen turn button for the chair")
        let handle = turn.frame
        turn.tap()
        tap(app, "Show panel")
        XCTAssertTrue(waitUntilEnabled(button(app, "Redo"), false), "the turn button didn't save an edit")
        let afterTurn = position(app, "Modern arm chair")
        XCTAssertNotEqual(afterTurn, movedRight)

        // A one-finger drag on the chair (just below its turn button) moves it along the floor.
        tap(app, "Hide panel")
        let window = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
        let onChair = window.withOffset(CGVector(dx: handle.midX, dy: handle.midY + 70))
        onChair.press(forDuration: 0.3, thenDragTo: onChair.withOffset(CGVector(dx: -60, dy: 25)))
        snapshot(app, "after-touch-drag")
        tap(app, "Show panel")
        let afterDrag = position(app, "Modern arm chair")
        XCTAssertNotEqual(afterDrag, afterTurn, "dragging the chair didn't move it")

        // Leave, terminate and relaunch against the same store: every saved item is still there.
        leaveRoomView(app)
        app.terminate()
        app = launch()
        waitForText(app, containing: "Scanned")
        for name in Self.fourAffinities { XCTAssertTrue(row(app, name).waitForExistence(timeout: 10), "\(name) missing after relaunch") }
        XCTAssertEqual(position(app, "Modern arm chair"), afterDrag, "the chair's saved position changed across relaunch")

        // Duplicate the design, then the counted permanent delete of the room.
        tap(app, "Duplicate")
        waitForText(app, containing: "Design A copy")
        showSidebar(app)
        tap(app, "Delete Room 1")
        waitForText(app, containing: "Delete 1 room and 2 designs? This can't be undone.")
        snapshot(app, "counted-delete-confirmation")
        tap(app, "Delete permanently")
        XCTAssertTrue(button(app, "Delete Room 1").waitForNonExistence(timeout: 10), "the room wasn't deleted")
        XCTAssertFalse(button(app, "Room 1").exists)
    }
}
