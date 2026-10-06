# Kfn8 iPhone + iPad Roadmap

**Goal:** an iPhone + iPad (iOS/iPadOS 27) app at feature parity with the Vision Pro app: scan a room, place true-scale furniture, keep Designs on the device, browse the online catalogue, compare and inventory Designs, export a room photo, and ship through TestFlight and the App Store.
**Architecture:** a fresh, independent Swift 6 / SwiftUI / RealityKit / ARKit app in [`_Kfn8-frontend-ios-src/`](_Kfn8-frontend-ios-src/), with its own copy of Kfn8Kit (domain, SwiftData persistence, catalogue client). It shares the backend, asset contract, bundled fixtures and Showroom design language with the Vision Pro app, but no Swift source.
**Specs:** [PRD.md](PRD.md), [TECHNICAL-PLAN.md](TECHNICAL-PLAN.md), [SALIENT-NOTES.md](SALIENT-NOTES.md). The Vision Pro [ROADMAP.md](ROADMAP.md) is the parity reference: each task below names the Vision Pro task it matches (→ E1.S4.T3).

> Status legend: ⬜ not started · 🟡 in progress · ✅ done · ⏸️ blocked/deferred · 🟢 verified on-device

## Founder decision D8 (2026-10-05)

D8 supersedes D7's "reuse as much code as possible".

- **Separate codebase.** The iPhone + iPad app is a fresh, independent codebase in `_Kfn8-frontend-ios-src`, at feature parity with the Vision Pro app.
- **Parity scope.** Parity includes:
  - room photo export,
  - the online catalogue,
  - realism and performance,
  - TestFlight and the App Store.
- **Supported devices.** Every iOS 27 iPhone and iPad. LiDAR devices get scan-mesh collisions and occlusion. Other devices get plane-only collisions, with a plain on-screen notice.
- **Kfn8Kit.** The app starts from a copy of Kfn8Kit and may diverge from it. Fixes no longer flow between the apps automatically.
- **Old target removed.** The earlier D7 `Kfn8iOS` target in the Vision Pro folder was removed on 2026-10-05. It remains in Git history, in the parent repository commit `0db5593`. The Vision Pro roadmap's Track IE is closed and points here.
- **App Store relationship: open.** Whether this is a separate App Store app or a universal purchase with the Vision Pro app is undecided. It must be decided before TestFlight (I7.S1.T1).

## Tracking rules

- **IDs.** Epics use the Vision Pro milestone numbers so parity is easy to see: I0 (M0), I1 (M1), I2 (M2), I3 (M3), I4 (M4), I7 (M7). There is no I5, because M5 is excluded in both apps. There is no I6, because private ingestion (M6) is backend-only and shared; it stays in the Vision Pro roadmap as E6.
- **Statuses.** Every Epic, Story and Task has a status.
- **✅** only when the acceptance evidence exists.
- **🟢** only for acceptance verified on a physical iPhone or iPad. Record the device model, iOS version and build. Simulator and host results never earn 🟢.
- **⏸️** names its blocker.
- **⬜** stays on work that hasn't started, even if it's next in line.
- **Updating.** Update Task statuses, Story/Epic rollups, the progress snapshot and the status table together, in the same change as the work or evidence.
- **Reports.** Evidence goes in `reports/IOS-*.md`.
- **No silent stubs.** Any unavoidable gap gets `TODO(kfn8-ios)` and is reported, never counted done.

Global constraints for every task:

- **Platform and code:** iOS/iPadOS 27 minimum, with no older-OS checks or shims. Swift 6 strict concurrency, with warnings treated as errors.
- **Privacy and business model:**
  - anonymous;
  - Spaces, Rooms, Designs, scans and world maps stay on the device and are never uploaded;
  - no accounts, sync or CloudKit;
  - no subscriptions or paywall;
  - no client analytics;
  - no watermark.
- **Use case:** indoor rooms only.
- **Assets:** the asset contract applies (metres, base-centre pivot, +Y up, front −Z, PBR metallic-roughness, ±1% across representations). Never generate or approximate a named purchasable SKU.
- **Look:** Showroom palette (bone/paper, walnut/clay, brass, ink) with no purple, indigo or cyan. Fraunces for display, Hanken Grotesk for UI.
- **Accessibility:** built in from the start, with a non-gesture path for every gesture.

## Progress snapshot

Last updated: 2026-10-06 (I1–I7 implemented and tested on the simulators; device runs and founder decisions outstanding). **56 tasks: 0 ⬜ not started · 18 🟡 in progress · 30 ✅ done · 8 ⏸️ blocked/deferred · 0 🟢 verified on-device.** Counts cover Tasks only.

Physical test devices visible to this Mac on 2026-10-04 (`devicectl list devices`):

| Device | iOS | LiDAR | Usable for evidence? |
|---|---|---|---|
| iPhone 13 Pro Max | 27.0 (24A5355q) | Yes | Yes |
| iPhone 16 Pro Max | 18.5 | Yes | Only after updating to iOS 27 |

No physical iPad and no non-LiDAR iPhone are paired. Until one is, iPad and non-LiDAR acceptance stays simulator-only and cannot reach 🟢; see decision ID-4.

## Open founder decisions

| ID | Decision | Needed before | Proposal |
|---|---|---|---|
| ID-1 | Separate App Store app or universal purchase with the Vision Pro app; final bundle ID | I7.S1.T1 (TestFlight) | Deferred by the founder ("decide later"). Working bundle ID `com.appliaison.kfn8.ios`, freed by the old target's removal |
| ID-2 | Performance acceptance target | I4.S2.T3 | Sustained 60 fps with zero dropped frames over 15 minutes, with 20 mixed placements and two virtual lights, on the oldest supported LiDAR iPhone available. ProMotion 120 Hz recorded but informational |
| ID-3 | iOS 27 has no equivalent of visionOS physical-space lighting: `SurroundingsLight` is `@available(iOS, unavailable)` ([SDK evidence](reports/IOS-SDK-API-EVIDENCE.md)). Accept the LiDAR-mesh `receivesLighting` route (LiDAR devices only), accept lighting of virtual items only, or re-scope | After I0.S2.T5 | Decide from the T5 device run; no workaround without a decision |
| ID-4 | Physical iPad and non-LiDAR iPhone for evidence | I1.S6, I7.S2 | Borrow or buy one of each, or explicitly accept simulator-only evidence for those classes |
| — | Shared with Vision Pro: DigitalOcean provisioning (E2.S2.T1), launch-library budget (E4.S1.T1), consumer release name (E7.S1.T1) | I2, I4, I7 | Tracked in [ROADMAP.md](ROADMAP.md) |

## Status / critical path

| Epic | Milestone | Status | Effort estimate | Exit dependency |
|---|---|---|---|---|
| I0 | Foundation and iOS feasibility | 🟡 foundation done; probe ready, device runs pending (T3–T6) | 1–2 weeks | Device probe evidence on a LiDAR iPhone |
| I1 | Scan, place and preserve | 🟡 built; simulator E2E green on iPhone and iPad; device demo pending | 3–5 weeks | Device demo (I1.S6.T2), ID-4 |
| I2 | Catalogue and offline assets | 🟡 download/revocation/updates verified on recorded responses; deployed run blocked | 1–2 weeks | DigitalOcean provisioning |
| I3 | Designs, inventory and photo export | 🟡 done on simulators; device photo pending | 2–3 weeks | Device photo (I3.S3.T2) |
| I4 | Realism and performance | 🟡 shadows/occlusion/lights/clearances/traces built; evidence needs device + library | 2–3 weeks | Launch library, ID-2, ID-3 |
| I7 | TestFlight and App Store | ⏸️ privacy/limitations and checklist drafted | 1–2 weeks + external review | ID-1, release name, all prior evidence |

## 🟡 Epic I0 — Foundation and iOS feasibility

### ✅ I0.S1 — Project foundation

- ✅ I0.S1.T1 Retire the D7 `Kfn8iOS` target from the Vision Pro folder. **Done 2026-10-05:**
  - **Removed:** `Kfn8/iOS/`, `Kfn8iOSUITests/`, the `Kfn8iOS`/`Kfn8iOSUITests` targets and scheme, and the iOS deployment target from `project.yml`; `.iOS` from the Vision Pro Kfn8Kit platforms; the iOS steps from `tools/ci.sh`; the iOS-only frame-rate branch in `PerformanceMonitor`.
  - **Icon tool:** `make_app_icon.py` now writes an iPhone/iPad icon only when given `--ios-catalog`.
  - **Checks:** the Vision Pro project regenerates with visionOS schemes only. Kfn8Kit is 67/67 on the host, the `Kfn8` app builds for the visionOS device and simulator SDKs, and the visionOS UI tests pass 4/4.
- ✅ I0.S1.T2 Create the xcodegen project in `_Kfn8-frontend-ios-src/` with `project.yml`, `setup.sh` (asks before opening Xcode; no Git), a README and a root ignore entry for the generated `.xcodeproj`.
  - **Target:** iOS 27.0, iPhone + iPad, Swift 6 strict concurrency, warnings as errors, team 9L38FSU6M7.
  - **Bundle ID:** working ID `com.appliaison.kfn8.ios` (ID-1).
  - **Info.plist:** camera usage text and `UIRequiredDeviceCapabilities: arkit`.
  - **Done 2026-10-05:** `Kfn8iOS.xcodeproj` generated from `project.yml`; `setup.sh`, README and ignore entry added; builds for the iOS device and simulator SDKs with no warnings. [report](reports/IOS-I0-FOUNDATION-2026-10-05.md)
- ✅ I0.S1.T3 Copy Kfn8Kit from the Vision Pro folder (as of 2026-10-05, including `realWorldContactTest`) into `Packages/Kfn8Kit`. Set the platforms to iOS 27 plus the macOS host. All copied tests pass. Record the copy's origin in its README.
  - **Done 2026-10-05:** 72/72 host tests (the 67 copied plus 5 new tests for the checksum-verified `BundledCatalogue` reader). [report](reports/IOS-I0-FOUNDATION-2026-10-05.md)
- ✅ I0.S1.T4 Bundle the nine conformed fixtures and their manifests, plus Fraunces and Hanken Grotesk with their OFL licences. `kfn8-validate --bundle` proves the bundled bytes match the backend manifests. Generate the app icon with `make_app_icon.py --ios-catalog`.
  - **Done 2026-10-05:** 9/9 PASS `kfn8-validate --bundle`; the reader loads all nine with verified LOD0 USDZ checksums; opaque 1024 px icon. [report](reports/IOS-I0-FOUNDATION-2026-10-05.md)
- ✅ I0.S1.T5 One-command CI, `tools/ci-ios.sh`:
  - copied-package tests;
  - the bundle check;
  - generated Swift transport models compared with `contracts/v1/openapi.json` (drift fails CI);
  - device and simulator builds;
  - with `--with-ui`, UI tests on the iPhone 18 Pro and iPad Pro 11-inch (M5) simulators.
  - **Done 2026-10-05:** `tools/ci-ios.sh --with-ui` PASSED, with UI tests 1/1 on iPhone 18 Pro and 1/1 on iPad Pro 11-inch (M5). UI steps fail unless the result bundle reports at least one executed, passing test. The generator gained `--out` for the drift check. [report](reports/IOS-I0-FOUNDATION-2026-10-05.md)
- ✅ I0.S1.T6 Labelled simulated room for the iOS simulator, which has no ARKit camera: a floor, a wall, a ceiling and one table as a real obstacle, labelled "simulated room (simulator only)" in the UI. It never counts as device evidence.
  - **Progress 2026-10-05:** `RoomCaptureMode` (simulated / camera and depth sensor / camera only, from ARKit at runtime) and the `SimulatedRoom` layout exist; the label is shown on the first screen and asserted by the UI test on both simulators. Drawing the room waits for the AR room view (I1.S5.T2). [report](reports/IOS-I0-FOUNDATION-2026-10-05.md)
  - **2026-10-06:** the simulated room is drawn in the room view (floor, wall, table through a virtual camera) and labelled; every UI test runs in it on both simulators. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)

Acceptance: a clean checkout runs `setup.sh` and `ci-ios.sh` to green without touching the Vision Pro folder.

### 🟡 I0.S2 — iOS platform feasibility (device evidence, → E0.S2)

- ✅ I0.S2.T1 Read the installed iOS 27 SDK and record the actual API for each capability in `reports/IOS-SDK-API-EVIDENCE.md`. Fail rather than invent APIs.
  - **Rendering stack:** choose between ARKit `ARSession` with RealityKit `ARView`, and `RealityView` with `SpatialTrackingSession`, based on what each actually exposes for:
    - plane classification;
    - the LiDAR scene mesh;
    - `ARWorldMap` save and relocalization;
    - people and scene-depth occlusion;
    - light estimation and environment texturing;
    - a camera-plus-content snapshot.
  - **Done 2026-10-05:** ARKit `ARSession` + RealityKit `ARView`, because `SpatialTrackingSession` has no world-map persistence. `SurroundingsLight` is iOS-unavailable, so the lighting candidate is the LiDAR mesh with `receivesLighting` (ID-3). [SDK evidence](reports/IOS-SDK-API-EVIDENCE.md)
- ✅ I0.S2.T2 Minimal nonshipping probe screen, with Swift Testing for its pure state.
  - **Done 2026-10-05:** `Kfn8iOSProbe` (seven pages, chips plus Record, evidence JSON) and `Kfn8iOSProbeCore` (10/10 host tests). The simulator smoke test passes 1/1 after a fix: truncated segmented tabs became full-label page buttons. In `ci-ios.sh`. [findings](reports/IOS-I0-FINDINGS.md)
- 🟡 I0.S2.T3 Relocalization on device: save a world map, relaunch and find the same room. Record the time to relocalize and the failure cases. A different room must show no false positioning.
  - **Probe ready 2026-10-05** (Find page); the device run on the iPhone 13 Pro Max is pending (founder, protocol in `_Kfn8-frontend-ios-src/README.md`). [findings](reports/IOS-I0-FINDINGS.md)
- 🟡 I0.S2.T4 LiDAR scan-mesh collision with the support-contact tolerance, and scan-mesh plus people occlusion, on a LiDAR iPhone. Record clean and failed edges.
  - **Probe ready 2026-10-05** (Collide and Occlude pages); the device run on the iPhone 13 Pro Max is pending (founder, protocol in `_Kfn8-frontend-ios-src/README.md`). [findings](reports/IOS-I0-FINDINGS.md)
- 🟡 I0.S2.T5 Lighting: virtual items lit by light estimation and environment texturing, and whether a virtual light can visibly light real surfaces. If it can't, raise ID-3.
  - **Probe ready 2026-10-05** (Light page); the device run on the iPhone 13 Pro Max is pending (founder, protocol in `_Kfn8-frontend-ios-src/README.md`). [findings](reports/IOS-I0-FINDINGS.md)
- 🟡 I0.S2.T6 Room photo: capture the camera image with the placed items, save it, reopen the file and confirm real room pixels and the furniture. Record the permission used (add-only Photos access, or the share sheet).
  - **Probe ready 2026-10-05** (Photo page); the device run on the iPhone 13 Pro Max is pending (founder, protocol in `_Kfn8-frontend-ios-src/README.md`). [findings](reports/IOS-I0-FINDINGS.md)

Acceptance: T3–T6 have device evidence on a LiDAR iPhone with device, iOS version and build recorded. A failure gets one short setup check, then stops with expected vs observed and options for the founder.

## 🟡 Epic I1 — Scan, place and preserve (→ E1)

### ✅ I1.S1 — Durable data and files (→ E1.S2)

- ✅ I1.S1.T1 Spaces, Rooms, Designs and Placements in SwiftData through the copied Kfn8Kit persistence actor. Tests cover create, open and restart against a real temporary store.
  - **2026-10-06:** Spaces/Rooms/Designs/Placements through the copied `LocalStore` (host tests); relaunch keeps every placement and its exact position (`testScanPlaceEditRelaunchDelete`, iPhone 18 Pro + iPad Pro 11-inch simulators). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S1.T2 Scans and world maps stored as local files, excluded from iCloud/iTunes backup, with checksums. A tampered scan is rejected.
  - **2026-10-06:** the store, scan files and world maps live under one Application Support folder marked excluded from backup; scans are checksum-verified on read and a tampered scan is rejected (host test). World-map contents are device-only (I1.S6.T2). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S1.T3 Atomic saves of completed edits only, never per frame. A failed write keeps the committed state, and save errors are always shown.
  - **2026-10-06:** drags and twists are previews; only release, nudges and buttons commit, with the optimistic version check (host tests; UI tests check positions after each edit and across relaunch). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S1.T4 Counted permanent delete ("Delete 1 room and 2 designs? This can't be undone.") with a deletion journal that finishes after a restart. Shared asset revisions stay pinned by surviving Designs.
  - **2026-10-06:** "Delete 1 room and 2 designs? This can't be undone." then the room is gone (iPhone 18 Pro + iPad Pro 11-inch simulators); the restart-safe deletion journal is host-tested. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)

### 🟡 I1.S2 — Capture and room frame (→ E1.S3.T1–T2)

- 🟡 I1.S2.T1 Camera permission with plain-language denied and restricted messages and a way to open Settings.
  - **2026-10-06:** implemented (permission request, plain-language denial with Open Settings). Device check pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I1.S2.T2 Plane classification (floor, wall, ceiling, table, seat) with coaching and coverage feedback while scanning.
  - **2026-10-06:** implemented (classification of floor/wall/ceiling/table/seat, ARKit coaching overlay, status line). Device check pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S2.T3 Room frame from the floor and the widest wall, with the room anchor kept separate from placement transforms. Tests show room-local placements survive different session origins.
  - **2026-10-06:** frame from the floor and the widest wall over 1 m, a named room anchor separate from placements; host tests show room-local placements survive different session origins. Plane conversion itself is checked on device in I1.S6.T2. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I1.S2.T4 LiDAR scan mesh for collisions and occlusion. Non-LiDAR devices show "No depth sensor: only floors, walls, tables and seats are checked for collisions." No silent fallback.
  - **2026-10-06:** implemented (LiDAR mesh collision + occlusion; camera-only devices use scanned-plane boxes and show the notice). Device check pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)

### 🟡 I1.S3 — Return visits and recovery (→ E1.S3.T3)

- 🟡 I1.S3.T1 Relocalization from the stored world map in bounded guided attempts, with content hidden until the room is verified.
  - **2026-10-06:** implemented (world map stored in the scan, bounded 8 s attempts, content hidden until the anchor is found, map refreshed on leaving). Device check pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S3.T2 "I can't tell where this room is yet" with two choices: **Rescan this room** (same Room, Designs kept) or **Review contents** (no positions or clearances shown).
  - **2026-10-06:** both choices on the simulators: rescan keeps the Design; review shows no positions, nudges or clearances (`testLostAlignmentRecoveryFlipAndInventory`). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I1.S3.T3 Session interruptions (app backgrounded, phone call, camera taken by another app) re-verify alignment, never assume it. Store a fresh world map when leaving an aligned room.
  - **2026-10-06:** implemented (interruption pauses, then re-verifies alignment against the anchor). Device check pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)

### 🟡 I1.S4 — Placement and touch manipulation (→ E1.S4.T2–T3)

- ✅ I1.S4.T1 One attachment system by affinity (floor, wall, ceiling, tabletop), with mount points separate from the base-centre pivot. Placement scale is always 1.
  - **2026-10-06:** one attachment system; one item per affinity placed in the simulated room on both simulators (host tests for the rules). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I1.S4.T2 Hard real-world collision with the scan-mesh tolerance, soft overlap between virtual items, rugs exempt, push-out of up to 25 cm on release, otherwise held unsaved and translucent with "There isn't enough space here" and **Cancel**. No distant jump, red styling or error modal.
  - **2026-10-06:** implemented (LiDAR sweep with `realWorldContactTest`, plane boxes on camera-only devices, push-out ≤25 cm, held translucent + Cancel, soft overlap, rugs exempt; host tests). Real-mesh behaviour is device-only (I0.S2.T4, I1.S6.T2). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S4.T3 New items appear in front of the camera at a handheld distance, facing the viewer.
  - **2026-10-06:** 1.5 m in front of the camera, facing it (shared `poseInFront`, host-tested; seen in the simulator captures). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I1.S4.T4 Touch gestures:
  - one-finger drag along the item's support surface;
  - two-finger twist to rotate;
  - no pinch-to-scale;
  - tap to select, double-tap to flip Designs.
  - **2026-10-06:** one-finger drag verified in the simulator UI test (the saved position changes); twist, tap-select and double-tap flip implemented. Device feel pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S4.T5 Non-gesture controls: an on-screen 45° turn button per item, plus panel buttons to move (Left/Right/Toward wall/Away from wall), Raise/Lower for wall items, Rotate ±15°, Cancel move, Remove, Undo and Redo.
  - **2026-10-06:** the on-screen 45° turn button, Left/Right/Rotate/Undo/Redo verified by saved-position checks on both simulators; Raise/Lower, Cancel move and Remove covered too. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)

### 🟡 I1.S5 — Interface and accessibility (→ E1.S4.T1, T4)

- ✅ I1.S5.T1 Showroom theme and fonts. iPhone uses a stacked navigation and iPad a split view. Portrait and landscape are both supported.
  - **2026-10-06:** Showroom palette and fonts pinned to the light appearance; iPhone stack, iPad split; all orientations. iPhone 18 Pro + iPad Pro 11-inch simulators. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S5.T2 A full-screen AR room view with a resizable panel holding the Design, Inventory and Catalogue sections, plus Leave and status/recovery banners.
  - **2026-10-06:** full-screen room view, iPhone sheet panel that collapses rather than dismisses, iPad inspector column, Leave, status and recovery banners. iPhone 18 Pro + iPad Pro 11-inch simulators. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I1.S5.T3 Item preview sheet: orbitable 3D, true scale when it fits, otherwise one uniform scale with the real W×D×H shown.
  - **2026-10-06:** orbitable preview with turn buttons and the real size ("Real size: W 181 × D 82 × H 71 cm"); a phone screen can't show true scale, so it says so and points to the room view. iPhone 18 Pro + iPad Pro 11-inch simulators. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I1.S5.T4 Accessibility:
  - VoiceOver reaches every control, including the in-scene turn buttons;
  - Dynamic Type at accessibility sizes doesn't clip;
  - Reduce Motion is respected.
  - **2026-10-06:** VoiceOver labels and position values on every control and placed item; the largest accessibility text size keeps every control reachable on both simulators after the layout fixes. VoiceOver (including the top bar while the panel is open) and Reduce Motion on a device are pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)

### 🟡 I1.S6 — M1-equivalent evidence (→ E1.S4.T5)

- ✅ I1.S6.T1 Simulator UI tests on iPhone and iPad:
  - create a space and room, then the simulated scan;
  - place one item per affinity plus the five batch-2 pieces;
  - move, rotate and undo;
  - a held invalid release;
  - relaunch and find everything;
  - both recovery choices;
  - counted delete;
  - tap the turn button;
  - open the preview sheet.
  - **2026-10-06:** six UI tests pass on both simulators (see the report's results). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I1.S6.T2 Device demo on the LiDAR iPhone, repeated on an iPad and a non-LiDAR iPhone when available (ID-4): scan, place all four affinities, move and cancel, save and relaunch, lose and recover alignment, delete. Record it in `reports/IOS-M1-FINDINGS.md`.
  - **2026-10-06:** the app is ready for the device demo; it needs the founder on the iPhone 13 Pro Max, and an iPad and a camera-only iPhone per ID-4. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)

## 🟡 Epic I2 — Catalogue and offline assets (→ E2)

### 🟡 I2.S1 — Remote catalogue, cache and revocation (→ E2.S2)

- 🟡 I2.S1.T1 Remote catalogue browsing (facets, search, pagination) through the copied client, with the base URL from configuration. Show "The online catalogue isn't connected in this build" while no backend is deployed.
  - **2026-10-06:** browse verified end to end against recorded responses; search, the affinity filter and cursor paging are implemented but only exercised against the deployed service (T5). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I2.S1.T2 Download, checksum and install to the asset cache. Pin exact revisions referenced by Designs, LRU-evict only unreferenced files, and report missing-offline and insufficient-storage explicitly.
  - **2026-10-06:** downloaded from the recorded catalogue with the model's real SHA-256 checked, placed, and remembered across launches; cache pins/LRU host-tested. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I2.S1.T3 Revocation sync on launch, foreground and an infrequent schedule (no heartbeat). An open scene isn't yanked; the next load shows a labelled absence and keeps the Placement record.
  - **2026-10-06:** a rights revocation applied on the next launch: the placement keeps its row, labelled "no longer available" in the Design and the inventory, with nothing substituted. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I2.S1.T4 Per-Design asset update offers with a change summary, never applied automatically.
  - **2026-10-06:** "A newer version … is available (revision 2)" offered per Design and applied only on Update (UI test). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ⏸️ I2.S1.T5 Deployed end-to-end test: browse, download, go offline, load, revoke, reconnect, reload, and repeat with a commercial delisting. **Becomes ⏸️ when reached** until DigitalOcean is provisioned (E2.S2.T1).
  - **Blocked:** needs the deployed catalogue (DigitalOcean provisioning, E2.S2.T1).

## 🟡 Epic I3 — Designs, inventory and photo export (→ E3)

### ✅ I3.S1 — Saved Designs and ordinary edits (→ E3.S1)

- ✅ I3.S1.T1 Autosave, rename and one-tap duplicate (new IDs, shared asset revisions). No history, conflicts or sync.
  - **2026-10-06:** every completed edit autosaves; rename and duplicate verified on both simulators. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I3.S1.T2 Session undo/redo and an atomic A/B flip (button and double-tap) that keeps the current Design on screen until the next one is fully loaded. A failed load keeps the current one.
  - **2026-10-06:** undo/redo and the A/B flip (button) verified on both simulators; the flip preloads models before switching; double-tap flip is a device check. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
### ✅ I3.S2 — Inventory and honest pricing (→ E3.S2)

- ✅ I3.S2.T1 Inventory: quantities and dimensions by default, no invented prices or links, no subtotal when nothing is priced. The priced path covers dated prices, "priced items only" when mixed, per-currency subtotals and delisted prices; tests use synthetic offers only.
  - **2026-10-06:** generic-only inventory shows quantities and no subtotal; with an online item: dated price, retailer link and "priced items only" (UI tests); currency/date rules host-tested. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
### 🟡 I3.S3 — Room photo export (→ E3.S3)

- ✅ I3.S3.T1 Room photo export with explicit consent for capturing your home. Save to Photos (add-only) or share. No watermark and no automatic upload. Handle denial, cancel and write failure.
  - **2026-10-06:** consent banner (decline captures nothing), capture, Save to Photos with add-only access, Share, temporary copy deleted on Done (UI test). Photos denial and write failure are handled in `PhotoExportFlow` (host tests). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I3.S3.T2 Open an exported photo on the device and confirm the real room plus furniture. Record that no analytics or geometry leaves the device.
  - **Device only:** the simulator photo shows the simulated room. Covered by I0.S2.T6 on the iPhone.

## 🟡 Epic I4 — Realism and performance (→ E4)

### 🟡 I4.S1 — Realism

- 🟡 I4.S1.T1 Grounding shadows, light estimation and environment texturing on every placement. Scan-mesh and people occlusion where the device supports them.
  - **2026-10-06:** grounding shadows on every placement, environment texturing, LiDAR and people occlusion configured. Device check pending. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- 🟡 I4.S1.T2 Up to two virtual lights, as decided under ID-3.
  - **2026-10-06:** the pendant and the sconce light the virtual furniture (at most two, "Lamps on" switch, host-tested plan). Lighting real surfaces waits for **ID-3**. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ✅ I4.S1.T3 Conservative clearance readings: gaps, not fit verdicts, with sensible rounding and ranges. Withheld with a rescan hint when the scan has too little coverage.
  - **2026-10-06:** the selected item shows gaps per side to scanned obstacles (walls, tables, seats), or a rescan hint; never a fit verdict; hidden in Review contents (UI test + host tests). [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ⏸️ I4.S1.T4 Compare against representative launch-library assets in repeatable room conditions; fix assets rather than hide contract violations. **⏸️ when reached** until the launch library exists (E4.S1.T1).
  - **Blocked:** the launch library (E4.S1.T1).

### 🟡 I4.S2 — Performance evidence

- ✅ I4.S2.T1 Local performance traces: frame-time distribution, dropped frames, memory, load times and thermal state, written to the app's Documents folder and never uploaded.
  - **2026-10-06:** `Documents/perf-<time>.json` written when the room view closes: frame-time distribution, dropped frames against 60 fps, memory each second, thermal states, model load times, `isSimulator`. [report](reports/IOS-IMPLEMENTATION-2026-10-06.md)
- ⏸️ I4.S2.T2 Tune LOD thresholds, draw calls and texture residency with representative assets, staying within the asset contract.
  - **Blocked:** representative launch-library assets and device traces.
- ⏸️ I4.S2.T3 Run 20 mixed placements and two lights for 15 minutes of walking and turning against the ID-2 target. Report p50/p95/p99/max, dropped frames and memory, with no average-only pass. **Needs the launch library and ID-2.**
  - **Blocked:** the launch library and decision ID-2.

## ⏸️ Epic I7 — TestFlight and App Store (→ E7)

### 🟡 I7.S1 — Release candidate

- ⏸️ I7.S1.T1 Resolve ID-1 (separate app or universal purchase) and the final bundle ID, and use the shared release name (E7.S1.T1).
  - **Blocked:** decision ID-1 and the shared release name (E7.S1.T1).
- 🟡 I7.S1.T2 Privacy declarations that match the shipped behaviour: camera, add-only Photos, no tracking, no data collected. Ship a limitations note covering no backup or restore, best-effort offline revocation and LiDAR-only features. Check font and asset licences.
  - **2026-10-06:** draft written: [IOS-LIMITATIONS-AND-PRIVACY.md](release/IOS-LIMITATIONS-AND-PRIVACY.md) and [IOS-RELEASE-CHECKLIST.md](release/IOS-RELEASE-CHECKLIST.md); to re-check against the release candidate.
- ⏸️ I7.S1.T3 Full device end-to-end run: scan, all four affinities, manipulation, save and relaunch, recovery, duplicate, A/B flip, inventory, photo export, delete, download and revocation. Fold in the accessibility checks.
  - **Blocked:** a release candidate and the device runs (I1.S6.T2, ID-4).

### ⏸️ I7.S2 — Distribution

- ⏸️ I7.S2.T1 Signed archive and TestFlight build; the founder runs the demo and gathers feedback. No population analytics claims.
  - **Blocked:** I7.S1 and the founder's approval to upload.
- ⏸️ I7.S2.T2 Fix blocking TestFlight findings, submit to App Review and record the actual outcome. Submission is not approval; this stays open until the outcome exists.
  - **Blocked:** TestFlight (I7.S2.T1).

Exit: every prior Epic has its evidence, the app is actually distributed, and the limitations and privacy text match shipped behaviour. Nothing is marked ✅ or 🟢 on "should work".
