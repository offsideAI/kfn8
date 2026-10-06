import XCTest

/// I1.S3 and I3 on the iPhone and iPad simulators: lost alignment with both recovery choices, A/B flip, rename,
/// the generic-only inventory, the five batch-2 pieces and the preview sheet. Not device evidence.
final class DesignsAndRecoveryTests: Kfn8TestCase {
    func testLostAlignmentRecoveryFlipAndInventory() throws {
        var app = launch()
        scanNewRoom(app)
        tap(app, "Add Modern arm chair")
        XCTAssertTrue(row(app, "Modern arm chair").waitForExistence(timeout: 15))
        waitForText(app, containing: "1 ×")
        XCTAssertFalse(text(app, containing: "priced items only").exists, "a generic-only inventory has no subtotal")
        XCTAssertFalse(text(app, containing: "each · checked").exists, "bundled generics carry no prices")

        // Rename, duplicate, remove the chair in the copy, then flip back and forth.
        tap(app, "Rename")
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Window side")
        app.alerts.buttons["Rename"].tap()
        waitForText(app, containing: "Window side")
        tap(app, "Duplicate")
        waitForText(app, containing: "Window side copy")
        selectRow(app, "Modern arm chair")
        tap(app, "Remove")
        waitForText(app, containing: "Nothing placed yet")
        tap(app, "Flip to Window side")
        XCTAssertTrue(row(app, "Modern arm chair").waitForExistence(timeout: 15), "flip didn't bring the chair back")
        tap(app, "Flip to Window side copy")
        waitForText(app, containing: "Nothing placed yet")
        tap(app, "Flip to Window side")
        XCTAssertTrue(row(app, "Modern arm chair").waitForExistence(timeout: 15))
        leaveRoomView(app)

        // Return visit where the room can't be found: bounded attempts, then rescan into the same Room.
        app.terminate()
        app = launch(["--simulate-lost-alignment"])
        tap(app, "Open room view")
        waitForText(app, containing: "I can't tell where this room is yet")
        XCTAssertFalse(button(app, "Turn Modern arm chair 45 degrees").exists, "no positions are shown before the room is found")
        snapshot(app, "recovery-choices")
        tap(app, "Rescan this room")
        waitForText(app, containing: "Aligned")
        XCTAssertTrue(row(app, "Modern arm chair").waitForExistence(timeout: 10), "designs survive a rescan")
        leaveRoomView(app)

        // The other choice: review the contents without placing them, and without clearances.
        app.terminate()
        app = launch(["--simulate-lost-alignment"])
        tap(app, "Open room view")
        waitForText(app, containing: "I can't tell where this room is yet")
        tap(app, "Review contents")
        XCTAssertTrue(button(app, "Leave room view").waitForNonExistence(timeout: 10))
        waitForText(app, containing: "Scanned")
        XCTAssertTrue(row(app, "Modern arm chair").exists)
        selectRow(app, "Modern arm chair")
        XCTAssertFalse(text(app, containing: "Clearances").exists, "review shows no clearances")
        XCTAssertFalse(button(app, "Right").exists, "review offers no positioning")
    }

    func testBatchTwoPiecesPreviewAndClearances() throws {
        let app = launch()
        scanNewRoom(app)
        for name in ["Tufted leather sofa", "Stone-top coffee table", "Oak side table", "Cube display shelves", "Leather ottoman"] {
            tap(app, "Add \(name)")
            XCTAssertTrue(row(app, name).waitForExistence(timeout: 15), "\(name) was not placed")
        }
        snapshot(app, "batch-two-placed")

        // Clearances for the selected item: gaps (or a rescan hint), never a fit verdict.
        selectRow(app, "Oak side table")
        waitForText(app, containing: "Clearances")
        XCTAssertTrue(text(app, containing: "gap").exists || text(app, containing: "rescan").exists)
        XCTAssertFalse(text(app, containing: "fits").exists)

        // The preview sheet states the real size.
        tap(app, "Preview Tufted leather sofa")
        waitForText(app, containing: "Real size: W 181 × D 82 × H 71 cm")
        waitForText(app, containing: "Open the room view to see it at true scale")
        XCTAssertTrue(text(app, containing: "3D preview of Tufted leather sofa").exists)
        tap(app, "Turn left")
        tap(app, "Done")
        XCTAssertTrue(button(app, "Done").waitForNonExistence(timeout: 5))
    }
}
