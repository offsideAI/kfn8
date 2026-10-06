import XCTest

/// I3.S3.T1 (room photo with consent) and I1.S5.T4 (largest text size) on the simulators. The simulator's photo is of
/// the labelled simulated room, so it is not evidence that a device photo contains the real room (I3.S3.T2).
final class PhotoAndAccessibilityTests: Kfn8TestCase {
    func testRoomPhotoNeedsConsentAndSavesOrShares() throws {
        let app = launch()
        scanNewRoom(app)
        tap(app, "Add Modern arm chair")
        XCTAssertTrue(row(app, "Modern arm chair").waitForExistence(timeout: 15))

        // Declining: nothing is captured.
        tap(app, "Photo")
        waitForText(app, containing: "The photo shows your home")
        app.buttons["Not now"].firstMatch.tap()
        XCTAssertFalse(app.navigationBars["Room photo"].waitForExistence(timeout: 2), "a photo was taken without consent")

        // Agreeing: the photo is taken and can be saved or shared.
        tap(app, "Photo")
        app.buttons["Take photo"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Room photo"].waitForExistence(timeout: 10))
        XCTAssertTrue(text(app, containing: "Photo of your room").exists)
        XCTAssertTrue(app.buttons["Share"].exists)
        snapshot(app, "room-photo")
        app.buttons["Save to Photos"].firstMatch.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Allow Full Access", "Allow Access"] where springboard.buttons[label].waitForExistence(timeout: 3) {
            springboard.buttons[label].tap()
            break
        }
        waitForText(app, containing: "Saved to Photos")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Room photo"].waitForNonExistence(timeout: 5))
    }

    func testLargestTextSizeKeepsControlsReachable() throws {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        scanNewRoom(app)
        tap(app, "Add Modern arm chair")
        XCTAssertTrue(row(app, "Modern arm chair").waitForExistence(timeout: 15))
        snapshot(app, "largest-text-room-view")
        for label in ["Undo", "Duplicate", "Right", "Rotate left 15°", "Remove", "Leave room view"] {
            let b = button(app, label)
            reveal(app, b) // lazily built controls appear once scrolled to
            XCTAssertTrue(b.exists && (b.isHittable || onScreen(app, b)), "\(label) can't be reached at the largest text size")
        }
        tap(app, "Right")
        tap(app, "Undo")
    }
}
