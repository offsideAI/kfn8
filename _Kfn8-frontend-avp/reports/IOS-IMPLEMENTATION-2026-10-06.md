# iPhone + iPad app: I1–I7 implementation, 2026-10-06

Built and tested on the Mac host and the iOS 27 simulators (iPhone 18 Pro, iPad Pro 11-inch (M5)). **Nothing here is device evidence.** Device-only acceptance stays 🟡 or ⏸️ in [ROADMAP-IOS.md](../ROADMAP-IOS.md).

## What was built (`_Kfn8-frontend-ios-src/Kfn8iOS`)

- **App model:** `AppModel` with Spaces, Rooms and Designs; completed-edit saves only; undo/redo; the A/B flip that waits for preload; inventory; update offers; clearances; lamps.
- **Persistence:** the Kfn8Kit copy's SwiftData store on its own actor, with scan files and world maps under an Application Support folder excluded from backup.
- **Room session (`RoomSession`):**
  - **On a device:** ARKit world tracking, horizontal and vertical plane classification, the LiDAR mesh (collision + occlusion), people occlusion, environment texturing and coaching. The room frame is derived from the floor and the widest wall; a named room anchor and the world map are stored in the scan, and the map is refreshed when leaving the room.
  - **Relocalization:** bounded 8 s guided attempts, with content hidden until verified.
  - **Interruptions:** alignment is re-verified after an interruption.
  - **Camera permission:** denial is handled with a link to Settings.
  - **On the simulator:** a labelled simulated room (floor, wall, table) seen through a virtual camera.
- **Placement:**
  - one attachment system by affinity;
  - hard real-world collision (LiDAR mesh sweep with `realWorldContactTest`; scanned-plane boxes on camera-only devices) and push-out of up to 25 cm, or held unsaved and translucent with Cancel;
  - soft overlap between virtual items, with rugs exempt;
  - new items 1.5 m in front of the camera, facing it.
- **Touch:**
  - one-finger drag along the item's support plane (`DragPlane`, host-tested);
  - two-finger twist (not for wall items);
  - tap to select, double-tap to flip;
  - an on-screen 45° turn button per floor, table or ceiling item, following it on screen.
- **Non-gesture controls:**
  - Left/Right/Toward wall/Away from wall;
  - Raise/Lower for wall items;
  - Rotate ±15°;
  - Cancel move, Remove, Undo/Redo.
  
  Each placed-item row has a VoiceOver value describing where the item is (e.g. "0.40 m right of centre, 2.90 m out from the wall, turned 45°").
- **Interface:**
  - Showroom palette and fonts, pinned to the light appearance;
  - iPhone stacked / iPad split navigation;
  - a full-screen room view with a panel (iPhone: a resizable sheet that collapses rather than dismisses; iPad: an inspector column);
  - a preview sheet with real W×D×H;
  - rows that turn into columns at accessibility text sizes.
- **Online catalogue (`RemoteCatalogue`):**
  - search, an affinity filter and cursor paging;
  - verified downloads into the pinned cache, remembered across launches (the Vision Pro app keeps them in memory only);
  - revocation sync at launch and on foreground;
  - labelled absences that keep the item's name;
  - per-Design update offers that work independently of the current search;
  - offers mapped into the priced inventory, with the retailer link.
- **Room photo:** asked for on screen after the panel is hidden (consent first). It's saved to Photos with add-only access or shared; the temporary copy is deleted when you're done; no watermark or upload.
- **Lighting and performance:** up to two lighting fixtures (pendant, sconce) light the virtual furniture (`LightingPlan`). A local performance trace with frame times, memory, thermal state and model loads is written to Documents when the room view closes.
- **Debug-only test hooks (compiled out of Release):** `--catalogue-fixtures <dir>` serves recorded catalogue responses from files; `--force-revocation-sync`; `--simulate-lost-alignment` (simulator only).

## Added to the Kfn8Kit copy (host-tested)

`DragPlane`, `LightingPlan`, `ClearanceSummary`, `PhotoExportFlow`, `DownloadedAssetIndex`, `Offer.pricedOffer`, `PricedOffer.amountText`, plus `BundledCatalogue` from I0.

## Defects found by testing myself, and fixed

1. **Dark-mode text:** item titles rendered white on the light panel → the app and its sheets are pinned to the light Showroom appearance.
2. **Presentations behind the panel (iPhone):** the panel is itself a sheet, so Preview and the photo consent dialog couldn't present behind it → Preview is presented from the panel; photo consent is an on-screen banner, and the panel is hidden for photos.
3. **Crash when saving a photo:** a Swift 6 isolation trap, because the block passed to `PHPhotoLibrary.performChanges` inherited main-actor isolation but runs on Photos' queue. Fixed with a nonisolated helper. The same fix went into the probe, together with ARKit `getCurrentWorldMap` and `ARView.snapshot` callbacks.
4. **Largest text size:**
   - labels broke mid-word → `AdaptiveStack` turns rows into columns;
   - scaled grid columns went wider than the panel → capped;
   - the top bar's buttons were pushed under the panel → buttons first, icon-only at accessibility sizes.
5. **Inventory for a withdrawn item:** it said "Unavailable item (unavailable)" → it keeps the name and gives the same reason as the Design row ("no longer available").
6. **Online catalogue:** search, filter and paging were missing; update offers depended on the current listing → fixed.
7. **The panel vanished when swiped down at its top** → it now collapses to its smallest height (Maps-style); "Hide panel" hides it.

Simulator test-harness findings (not app defects):

- On iPhone, with the panel sheet up, XCUITest's accessibility hit-test reports the room view's top bar as unhittable even though touches reach it. Verified by tapping "Hide panel" by coordinate: the panel hid. The tests tap there as a finger would and check the effect. VoiceOver reachability of the top bar while the panel is open stays a device check (I1.S5.T4).
- Lazily built grid controls don't exist while scrolled away, so the tests scroll to find them.

## Results (final runs, 2026-10-06)

`tools/ci-ios.sh --with-ui`: **iOS CI PASSED**. The UI tests ran on one simulator at a time, because parallel clones were killed under load.

| Check | Result |
|---|---|
| Swift transport models vs `contracts/v1/openapi.json` | Up to date |
| Bundled catalogue vs backend manifests | 9/9 PASS |
| Kfn8Kit host tests | 84/84 (10 catalogue client, 54 domain, 20 catalogue and persistence) |
| Probe core host tests | 10/10 |
| App and probe builds, iOS device and simulator SDKs; app Release build | Succeeded, no warnings |
| UI tests, iPhone 18 Pro (iOS 27.0 simulator) | **6/6** |
| UI tests, iPad Pro 11-inch (M5) (iOS 27.0 simulator) | **6/6** |
| Probe smoke test, iPhone 18 Pro | 1/1 |

The six UI tests:

- **`testScanPlaceEditRelaunchDelete`:**
  - scan, then one item per affinity, with the lamp switch shown for the two lights;
  - Right, Rotate and Undo/Redo checked against the saved position;
  - the on-screen 45° turn button and a one-finger drag, both changing the saved position;
  - leave and relaunch with the exact position kept;
  - duplicate, then the counted delete.
- **`testLostAlignmentRecoveryFlipAndInventory`:**
  - the generic inventory with no prices or subtotal;
  - rename, duplicate, remove, then the A/B flip both ways;
  - lost alignment, then Rescan (Design kept);
  - lost alignment, then Review contents (no positions, nudges or clearances).
- **`testBatchTwoPiecesPreviewAndClearances`:** the five batch-2 pieces placed; clearances for the side table; the preview sheet's real size and turn buttons.
- **`testRoomPhotoNeedsConsentAndSavesOrShares`:** declining captures nothing; taking a photo offers Share and Save to Photos (add-only prompt), which reports "Saved to Photos"; Done deletes the temporary file.
- **`testLargestTextSizeKeepsControlsReachable`:** at Accessibility XXXL, Undo, Duplicate, Right, Rotate, Remove and Leave are all reachable and work.
- **`testBrowseDownloadPlacePriceUpdateAndRevoke`:** download with the real SHA-256 checked; place; dated price, retailer link and "priced items only"; relaunch; revision 2 offered and accepted; rights revocation, then "Leather pouf (no longer available)" in the Design and the inventory, and it's no longer offered.

Performance trace written by the app on the iPhone simulator when the room view closed (`Documents/perf-1791277122.json`):

- `isSimulator: true`;
- 4 placements, 2 active lights, 107 s;
- 5,941 frames: p50 16.7 ms, p95 18.3 ms, p99 65.2 ms, 220 dropped against 60 fps;
- model loads of 108–147 ms;
- 105 memory samples, peak 109 MB;
- thermal state nominal.

These are simulator numbers and are no evidence for ID-2.

## Not done (device or founder)

- **Device runs:** I0.S2.T3–T6 probes; I1.S6.T2 demo; I3.S3.T2 photo of the real room.
- **Device checks:** VoiceOver (including the top bar while the panel is open) and Reduce Motion; the feel of twist and double-tap.
- **Founder decisions:** ID-1 to ID-4.
- **External dependencies:** DigitalOcean (I2.S1.T5), the launch library (I4.S1.T4, I4.S2.T2–T3), TestFlight and App Review (I7).
