# Kfn8 Implementation Roadmap

> Execution: use the executing-plans workflow task by task. Routine approval pauses were waived by the founder on 2026-09-19. Feasibility failures and missing external dependencies still stop dependent work.

**Goal:** deliver the agreed anonymous, indoor visionOS 27 MVP1 with measured spatial accuracy, durable local Designs and a validated generic catalogue.
**Architecture:** Swift 6/SwiftUI/RealityKit/ARKit with SwiftData domain records and local files; separate async FastAPI/Postgres catalogue and private operator ingestion; published assets from Spaces CDN.
**Spec:** [TECHNICAL-PLAN.md](TECHNICAL-PLAN.md), [PRD.md](PRD.md), [SALIENT-NOTES.md](SALIENT-NOTES.md), interview Q1–Q55.

> Status legend: ⬜ not started · 🟡 in progress · ✅ done · ⏸️ blocked/deferred · 🟢 verified on-device

## Repository maintenance

✅ Root `.gitignore` consolidated for Swift/Xcode, Python and local configuration; redundant client ignore file removed. Source assets, shared project configuration and evidence remain versionable. Only the parent `.git` remains. Plan/PRD/README now describe one monorepo. No Git commands were run in this review; tracked-file state and branch identity were not inspected. Existing readiness tests: 8 passed; legacy project file syntax: valid. These housekeeping results do not close device-gated milestone tasks.

## Founder decision D5 (2026-09-23)

The founder directed implementation of all Epics on the visionOS 27 simulator without further headset sessions for now. M0 status at that point: lighting recorded **passed** on the M2; occlusion recorded failed in the comparison mode (ambiguous); manipulation transcript shows no post-release transform updates (continuation without re-grab is not platform behaviour). Consequences: M1+ work proceeds; every acceptance criterion that needs a physical headset stays 🟡 or ⏸️ with the reason stated; nothing is marked 🟢 from simulator results; external dependencies (cloud credentials, launch-library budget, App Review) remain blockers where reached.

## Founder decision D7 (2026-09-23): iPhone + iPad track

The founder directed a second client, an iPhone + iPad (iOS/iPadOS 27) version of the same app, reusing as much of the visionOS code as possible. It is a **separate track (IE1–IE6)** with its own target and scheme (`Kfn8iOS`), its own task counts and its own evidence. It does not add scope to, or change the acceptance of, the seven MVP1 Epics below; the visionOS MVP1 constraints (no iOS target *inside MVP1*, Mixed Immersive Space only) still govern E0–E7. Shared code: `Kfn8Kit` (Domain, Persistence, Catalogue) unchanged, plus the app model, catalogue loaders, Showroom theme, panels and room/placement logic. Platform code: visionOS keeps ImmersiveSpace/ManipulationComponent/visionOS ARKit providers; iOS uses `ARView` with `ARWorldTrackingConfiguration` (plane classification, LiDAR scene mesh where present), touch gestures and a camera permission. 🟢 stays reserved for physical-headset verification; iPhone/iPad device verification is recorded in the task text with device/build, never as 🟢.

## Tracking rules

Exactly seven Epics map one-to-one to M0, M1, M2, M3, M4, M6, M7. M5 and v1.1 work are excluded, not hidden in future tasks. IDs: E{milestone}.S{story}.T{task}. Assign a status to every Epic, Story and Task. Mark ✅ only when its acceptance evidence exists; reserve 🟢 for completed acceptance verified on a physical headset, with device/build and evidence linked in the milestone report. Record actual commands/results, build/commit IDs and demo evidence in `reports/M{n}-FINDINGS.md`. Mark ⏸️ when a concrete blocker or deliberate deferral prevents progress, and name the dependency. Future work awaiting the normal milestone sequence stays ⬜; dependency order alone does not mean work has started. Use 🟡 for partially implemented work that is still progressing. An Epic or Story is complete only when every required child and its acceptance criteria are complete; device-dependent acceptance cannot close on tooling tests alone. Update task statuses, Story/Epic rollups, the status table and progress snapshot in the same change as implementation or new verification evidence. Preserve evidence links and record blockers when they change. Estimates are effort, not deadlines.

Global constraints apply to every task: visionOS 27 only, Swift 6 strict concurrency, no older-OS branch, AVP only, indoor Mixed Immersive Space, no account/sync/paywall/telemetry/geometry upload, no queue/worker/tenant frontend, no generated named-SKU geometry, no UI purple/indigo/cyan. Asset revisions immutable; mesh contract ±1% across all representations. Accessibility built inline. No silent stubs; any unavoidable incomplete code gets `TODO(kfn8)` and is reported, never counted done.

## Progress snapshot

Last updated: 2026-10-04 (snapshot corrected to match task records; E0.S3.T1 deferred by the founder). **71 tasks: 0 ⬜ not started · 17 🟡 in progress · 35 ✅ done · 19 ⏸️ blocked/deferred · 0 🟢 verified on-device.** Counts cover Tasks only, not Story/Epic rollups. The separate iPhone + iPad track (D7) is counted in its own section: 23 tasks, 11 ✅ · 9 🟡 · 1 ⏸️ · 2 ⬜.

M0: E0.S1 is complete (Xcode 27 licence accepted, readiness exits 0 with `toolchain_ready_device_unverified`, signed probe installed on the M2 under team OffsideAI Inc. 9L38FSU6M7). Device runs 2–5 on the M2 (visionOS 27.0) recorded physical-space lighting passed (2026-09-22) and occlusion passed (2026-09-23, founder-confirmed, no captures, so not 🟢); manipulation sends no transform updates after release, and decision D6 accepts held-unsaved + re-pinch or Cancel. The splat attempt is spent and recorded as not ingestible. The export probe (E0.S3.T1) has not run on the headset and was deferred by the founder on 2026-10-04, so E3.S3 export stays blocked until it runs or export is re-scoped. D5 (2026-09-23): E1–E7 implemented and tested on the host and visionOS 27 simulator; device acceptance, DigitalOcean provisioning, the launch-library budget and the release name remain open. 2026-09-26: five more CC0 Poly Haven fixtures conformed and bundled (9/9 pass contract v1); their founder approvals are pending. Evidence: [M0 findings](reports/M0-FINDINGS.md), [SDK API evidence](reports/M0-SDK-API-EVIDENCE.md), [implementation report](reports/IMPLEMENTATION-2026-09-23.md), [readiness 2026-09-22](reports/M0-READINESS-2026-09-22.json), [readiness 2026-09-19 blocked](reports/M0-READINESS.json). Earlier nested-repository commit IDs are historical only; that metadata was removed at the founder’s request. They are not revisions in the parent monorepo.

## Status / critical path

| Epic | Milestone | Status | Effort estimate | Exit dependency |
|---|---|---|---|---|
| E0 | M0 Feasibility | 🟡 all three blocking gates resolved on M2 (lighting ✅, occlusion ✅, manipulation via D6); export probe deferred by founder 2026-10-04; final findings pending | 3–7 days | Export probe or re-scope decision |
| E1 | M1 Scan and place | 🟡 implemented; host + simulator E2E pass; approvals and device acceptance pending | 3–5 weeks | Fixture approvals, device demo |
| E2 | M2 Catalogue | 🟡 API/DB/client/cache/revocation done and tested; deployment blocked | 2–3 weeks | DigitalOcean provisioning and credentials |
| E3 | M3 Designs | 🟡 Designs/undo/A-B/inventory done; export blocked on M0 finding | 2–3 weeks | Export feasibility decision |
| E4 | M4 Realism | 🟡 instrumentation + clearance logic done; evidence needs device and launch library | 2–4 weeks | Launch-library budget, M2 traces |
| E6 | M6 Private ingestion | 🟡 staged pipeline done and tested locally; approvals and CDN pending | 2–3 weeks | Founder approvals, provisioning |
| E7 | M7 Release | ⏸️ docs drafted; release name, library, TestFlight pending | 1–2 weeks + external review | All preceding evidence, launch library |

External dependencies: Xcode 27 toolchain/signing/headset readiness gates M0; launch-library budgeting/acquisition follows M0 and gates E4/performance/release. Do not mistake the four low-poly fixtures for a launch library. M2/M6 completion records the monorepo revision when a commit is explicitly authorised, component build IDs and contract hash; the milestone report is not evidence that the backend was deployed.

## 🟡 Epic E0 — M0: prove the platform

### ✅ E0.S1 — Reproducible development readiness

As the operator, I can determine why the exact supported toolchain/device is or is not ready.

- ✅ E0.S1.T1 Inspect both source documents, interview decisions, repository status and installed toolchains; record paths/version evidence without altering global Xcode selection.
- ✅ E0.S1.T2 Implement `tools/check_m0_readiness.py` and tests: explicit developer directory, Xcode version, device/simulator SDKs, Swift 6+, command errors/timeouts, fail-closed exit code, explicit device-evidence warning. Test valid/wrong SDK, licence refusal, missing executable and timeout. Capture a real run in the M0 report.
- ✅ E0.S1.T3 Complete founder's Xcode licence review/acceptance, first-launch components, signing and M2 pairing; verify a signed visionOS 27-only build deploys. No automated agreement acceptance. **Done 2026-09-22:** licence accepted by the founder; SDKs xros27.0/xrsimulator27.0, Swift 6.4; readiness exits 0; founder signed into Xcode 27 (team OffsideAI Inc., 9L38FSU6M7), paired the M2 and updated it to visionOS 27.0 (24M362); `xcodebuild -allowProvisioningUpdates` signs with `Apple Development: Arunabh Das` and an automatic profile; `devicectl device install app` installed `com.appliaison.kfn8.m0probe` 0.0.1 on the headset. First launch is the founder's. Earlier blocker history: `xcodebuild -allowProvisioningUpdates` fails with “No Account for Team” for both G7Y435RZV6 (legacy project) and G4Y5TXVX4P (the only Apple Development certificate on this Mac); `devicectl list devices` shows no physical Vision Pro paired, only the simulator. Founder signed in on 2026-09-22, but the account's team does not match either ID; founder must supply the Team ID shown in Xcode → Settings → Accounts. **Device side cleared 2026-09-22 evening:** M2 paired over local network, Developer Mode enabled, headset updated to visionOS 27.0 (24M362), `devicectl device info ddiServices` reports the 27A266a developer disk image compatible. Only signing remains.
- ✅ E0.S1.T4 Set up client/backend component boundaries inside the existing `kfn8` monorepo; retain source/assets/screenshots and use shared root ignore rules. Await the founder’s source-directory rename, then set up the Swift 6 strict-concurrency M0 target. **Done 2026-09-22:** the empty misspelled directory was renamed to `_Kfn8-frontend-avp-src` (it was empty, so nothing else moved); `project.yml` (xcodegen) defines the `Kfn8M0Probe` visionOS 27.0-only target with `SWIFT_STRICT_CONCURRENCY=complete`, Swift 6 language mode and warnings as errors; local package `Kfn8M0ProbeCore`. Backend directory remains empty by plan (its first content is E1.S1.T2). No nested repositories or Git operations without explicit approval.

Acceptance: readiness reports actual command failures; signed build runs on M2. Tools passing in isolation does not complete this story.
Demo: run readiness command with Xcode 27; inspect SDK/version evidence; launch signed probe on headset.

### 🟡 E0.S2 — Blocking spatial-capability evidence

- ✅ E0.S2.T1 Read exact installed SDK declarations and Apple samples for physical-space lighting, Environment Occlusion and ManipulationComponent; record public API names and permissions in report. Fail rather than invent APIs. **Done 2026-09-22:** [M0-SDK-API-EVIDENCE.md](reports/M0-SDK-API-EVIDENCE.md) cites `PointLightComponent.SurroundingsLight`/`SpotLightComponent.SurroundingsLight` (visionOS 27.0), `EnvironmentBlendingComponent.occluded(by: .surroundings)` (26.0), `ManipulationComponent`/`ManipulationEvents` (26.0), export and splat routes, and ARKit permissions. Apple sample code was not available offline; the swiftinterface files are the authority.
- ✅ E0.S2.T2 Implement minimal nonshipping Mixed Immersive probe with Swift Testing for its pure control state; build device/simulator configurations with strict concurrency and no shims. **Done 2026-09-22:** `Kfn8M0Probe` builds for `generic/platform=visionOS` and `visionOS Simulator` (unsigned compile checks); 41 Swift Testing tests pass via `swift test` on the host and via the scheme on the visionOS 27.0 simulator (one JSON round-trip test initially failed on sub-second timestamp precision and was fixed before this status was set). No `#available` checks. The only conditional is `#if canImport(ScreenCaptureKit)` because the simulator SDK ships no such framework.
- ✅ E0.S2.T3 Measure virtual lamp contribution on a real wall/floor: recorded room/light setup, on/off comparison, capture/numerical evidence and frame behavior. No appearance-only assertion. **Passed on the M2 2026-09-22 (founder-recorded):** `PointLight + SurroundingsLight` brightened the real wall and floor, toggling matched notes, intensities and frame times logged; distribution uneven on the coarse scene mesh. [Run 3](reports/evidence/2026-09-22-device-M0-EVIDENCE-run3.json). On/off screenshots would upgrade it to 🟢.
- ✅ E0.S2.T4 Walk a virtual object behind real furniture and inspect occlusion edges while turning/moving; record repeatable artifacts, not just static screenshots. **Passed on the M2 2026-09-23 (founder-confirmed):** real furniture hid a block using the shipping app's occlusion setting; edges clean while still; no lag or flicker reported while moving, though that was not separately recorded. [Run 5 evidence](reports/evidence/2026-09-23-device-M0-EVIDENCE-run5.json), [M0 findings](reports/M0-FINDINGS.md). Not 🟢: the record came from a chat confirmation, not captures.
- 🟡 E0.S2.T5 Exercise direct/indirect manipulation, all four attachment policies, invalid-release continuation without re-grab, cancel, and volume handoff; capture expected/observed behavior. **Blocking question settled 2026-09-23:** across every M2 run visionOS sent zero transform updates after release, so continuation without re-grab is impossible; founder decision **D6** accepts held-unsaved + re-pinch or Cancel (already implemented). Observed on device: indirect pinch drags, `.stay` release, held-invalid and valid releases (floor, wall, tabletop). Still to observe on device, folded into the M1 device demo: direct grab, ceiling attachment, volume-to-room hand-off.
- ✅ E0.S2.T6 For any failure allow one minutes-long obvious-setup check; if unresolved, document options/costs and STOP before M1. Do not write a fallback renderer/gesture system. **Done:** the lighting check (dim default, no scene understanding) and the occlusion check (clay block without occlusion) both found probe mistakes, and both capabilities then passed. Manipulation's release limit went to the founder with options and was resolved by D6. No fallback renderer or gesture system was written.

Acceptance: three capability gates have device evidence and meet intended behavior; persistent quality shortfall is a failure, not “partial pass”.
Demo: founder executes T3–T5 on M2 with probe build ID and returns local traces/observations.

### 🟡 E0.S3 — Bounded nonblocking investigations and findings

- ⏸️ E0.S3.T1 Test an actual passthrough-plus-placements export: write file, open file, inspect real room pixels, permissions and distribution restrictions. Record unavailable rather than substitute furniture-only image. **Progress:** consent-gated ScreenCaptureKit picker/stream probe implemented (the only third-party route in the visionOS 27 SDK; `SCScreenshotManager` is unavailable, ARKit camera access needs an enterprise entitlement). Device run and file inspection pending. **Deferred by the founder 2026-10-04:** skipped for now; E3.S3 stays blocked until the device run or an export re-scope decision.
- ✅ E0.S3.T2 Spend only a few minutes on the approved Postshot candidate: obtain an ingestible file quickly or record “no readily available splat asset in a RealityKit-ingestable form”; one attempt, no debugging/search/conversion project. If it works record bytes/load time/frame behavior alongside meshes; note ~2M size and v1.1 conversion implication. **Done 2026-09-22, budget spent:** the page offers only a Box folder (browser interaction, no direct URL) with PLY files (~719k splats, 159 MB uncompressed); RealityKit 27 exposes `GaussianSplatResource` with a raw buffer initialiser only and no PLY/SPZ loader. Recorded as no readily available ingestible asset; v1.1 would need a PLY-to-buffer conversion step.
- 🟡 E0.S3.T3 Complete `reports/M0-FINDINGS.md` with exact versions, methodology, measurements, captures, separate blocking/nonblocking outcomes and M1 go/no-go. Export limitation requires a product scope decision before M3, not an M0 failure. **Progress:** readiness findings are written; device measurements and final M0 conclusions are not yet available.

Exit: E0.S1/S2 accepted by evidence, S3 findings recorded. No routine sign-off pause, but founder decisions remain required for unresolved product/platform failures.

## 🟡 Epic E1 — M1: scan, attach and preserve a room

### ✅ E1.S1 — First four assets and early contract gate

- ✅ E1.S1.T1 Acquire only approved chair/sconce/pendant/vase; record source/licence/author/attribution/evidence and dimension authority for each in backend ledger. No launch-library purchases. **Done 2026-09-23:** 1k glTF sources downloaded from the Poly Haven API with md5 verification into `_Kfn8-backend-fastapi/assets-source/`; licence page and per-asset info/file JSON saved under `ledger/evidence/` and hashed into each manifest. Sconce: the source is a kit; variant `_a` (one complete sconce) was selected.
- ✅ E1.S1.T2 Establish backend-owned `contracts/v1/asset.schema.json`, contract document, minimal ledger/approval migrations and validator CLI; tests reject missing evidence, wrong units/pivot/orientation, malformed data, dimension drift and texture/triangle overages. **Progress 2026-09-23:** schema, `ASSET-CONTRACT.md` and `kfn8-validate` done, measuring real GLB (node transforms, triangles, embedded textures, material model) and USDZ (metersPerUnit, upAxis, world bounds, UsdPreviewSurface); 18 pytest tests pass covering every listed rejection plus cross-format drift, corruption and CLI exit codes. Ledger/approval tables shipped in Alembic 0001 (`licence_ledger`, `approval`) with hash CHECKs, tested on real Postgres.
- ✅ E1.S1.T3 Conform four meshes, produce GLB master/LODs/USDZ, verify ±1% dimensions against declared spec across formats, record approvals. Fail unsupported conversion rather than ship a placeholder. **Done 2026-09-23:** chair, pendant, vase and the founder-chosen `industrial_wall_sconce` conformed (Blender 5.2.1: −Z front, base-centre pivot, GLB LOD0–2 + USDZ), 4/4 pass contract v1 and the bundle check; provenance and visual/dimension approvals by OffsideAI recorded in each manifest, bound to input fingerprints (`kfn8-validate --require-approvals` passes 4/4). The review sheet caught a backwards-facing orientation bug before approval (fixed); the caged sconce was declined and kept in `ledger/rejected/`. Evidence: `ledger/review-sheet-2026-09-23.png`, `ledger/review-sheet-sconce-2026-09-23.png`, `ledger/validation-2026-09-23.json`.
- ✅ E1.S1.T4 Bundle four verified placement renditions and manifests; CI validates same manifests/bytes. Keep the splat out of the shipping bundle and mesh gate. **Done 2026-09-23:** LOD0 USDZ + manifests in `Kfn8/Resources/Catalogue`; `kfn8-validate --bundle` proves byte identity and re-measures geometry; wired into `tools/ci.sh`. No splat bundled.

Acceptance: exactly four functional engineering models cover all affinities with traceable evidence and validator reports.
Demo: inspect each item's source/licence, dimensions and variant/rendition manifest; deliberately corrupt a copy and observe rejection.

**Founder request 2026-09-26: fixtures batch 2 (outside E1.S1's four-model gate, not the launch library).**
- **Items:** five generic CC0 floor pieces from Poly Haven, added to the bundled default set:
  - Tufted leather sofa (`sofa_02`)
  - Stone-top coffee table (`modern_coffee_table_01`)
  - Oak side table (`side_table_01`)
  - Cube display shelves (`wooden_display_shelves_01`)
  - Leather ottoman (`Ottoman_01`)
- **Excluded:** "Mid Century Lounge Chair", as a likely copy of a named design.
- **Fetch:** `tools/fetch_polyhaven.py` saves the API info/files JSON as evidence and MD5-checks every file.
- **Conform:** Blender 5.2.1. The coffee table and shelves needed a 90° turn so their long side and cubbies face −Z; the others 180°.
- **Checks:** 9/9 manifests pass contract v1 and the bundle byte check. `testBatchTwoFurniturePlaces` passes on the visionOS, iPhone 18 Pro and iPad Pro 11-inch simulators.
- **Pending:** founder provenance and visual/dimension approvals against `_Kfn8-backend-fastapi/ledger/review-sheet-batch2-2026-09-26.png`. `--require-approvals` currently passes the original 4 and fails these 5.

### ✅ E1.S2 — Durable domain and local files

- ✅ E1.S2.T1 Add Sendable domain values, repository protocols and explicit persistence actor/ModelContext isolation. Swift Testing verifies completed-edit counter, immutable revision references and rigid transforms. **Done 2026-09-23:** `Kfn8Domain` + `DesignRepository` protocol; `LocalStore` is a `ModelActor` and returns only domain values; tests in `_Kfn8-frontend-avp-src/Packages/Kfn8Kit` (edits/inverses/version counter, duplication, rigid transforms, room frames).
- ✅ E1.S2.T2 Implement SwiftData Space/Room/Design/Placement records plus file references; no CloudKit. Integration tests create/open/restart a real temporary store and verify schema migration baseline. **Done 2026-09-23:** `Kfn8SchemaV1` + migration plan, `cloudKitDatabase: .none`; on-disk store reopened in a new container keeps committed state (test `createOpenRestartKeepsCommittedState`).
- ✅ E1.S2.T3 Implement atomic completed-edit saves, surfaced save failures and interrupted-drag recovery; test failed write preserves committed state. No revision-history table. **Done 2026-09-23:** optimistic-version atomic commit with rollback; failed scan write keeps the previous scan; drags are previews until release, so a crash mid-drag restores the last committed edit; the app surfaces every save error.
- ✅ E1.S2.T4 Implement counted permanent-delete confirmation and restart-safe file deletion journal; verify actual scan removal and surviving Design references. No trash/archive. **Done 2026-09-23:** counted copy “Delete 1 room and 2 designs? This can't be undone.”; deletion journal finishes on relaunch after a simulated IO failure; shared revision still pinned by the surviving Design.

Acceptance: terminated sessions recover committed state; files and records remain consistent; sensitive records never uploaded.
Demo: save placement, terminate/relaunch, delete Room with another Room sharing an asset, inspect retained asset and removed scan.

### 🟡 E1.S3 — Capture and verified room recovery

- 🟡 E1.S3.T1 Implement permission-aware capture/classification for floor/wall/ceiling/horizontal support, coverage feedback and local file storage. Preserve structured elements returned by the same scan without UI/features. **Implemented:** world-sensing authorization, PlaneDetection (floor/wall/ceiling/table/seat/bed), SceneReconstruction collision meshes, structured planes stored locally as the scan file. Simulator E2E `Kfn8UITests` passes on visionOS 27.0 (labelled simulated room); device acceptance pending. Coverage feedback beyond status text and real-room capture quality are device items.
- ✅ E1.S3.T2 Establish floor/wall-derived room frame and separate session alignment/world anchor; test transform composition and reattachment without modifying placement transforms. **Done 2026-09-23:** `RoomFrame.derive`, `sessionFromRoom × placement`, world-anchor ID stored separately; tests prove room-local placements survive different session origins.
- 🟡 E1.S3.T3 Implement bounded guided alignment, then same-Room rescan or content-only review. Verify ambiguity does not display false positioning; no separate new-device flow. **Implemented:** two guided attempts (8 s each on device), spatial content hidden until verified, “I can't tell where this room is yet”, rescan into the same Room and review contents. Simulator UI test `testLostAlignmentRecoveryAndDesignFlip` passes both choices. Real relocalization/ambiguity is a device item.

Acceptance: same Room survives lost anchor without lost Designs; review has no clearances or passthrough composition.
Demo: save in a room, return/relocalize, force missing alignment and exercise both recovery choices.

### 🟡 E1.S4 — Affinity-driven manipulation and accessible shell

- ✅ E1.S4.T1 Implement Window/Volume/Mixed scene ownership, Showroom tokens/fonts/licences and deterministic preview fit; pure tests cover oversized and 1:1 previews. **Done 2026-09-23:** main window, volumetric preview (uniform downscale with real W×D×H), Mixed Immersive Space; Showroom palette; Fraunces + Hanken Grotesk with OFL files; `PreviewFit` tests.
- 🟡 E1.S4.T2 Implement one attachment policy system, mounting metadata separate from pivot, permanent placement scale 1; verify real wall asset, pendant, chair and vase on device. **Implemented + unit-tested:** one `Attachment` policy by affinity, gravity drop, mount points for wall/ceiling, scale gestures disabled. Simulator E2E `Kfn8UITests` passes on visionOS 27.0 (labelled simulated room); device acceptance pending.
- 🟡 E1.S4.T3 Implement hard real collision / soft virtual overlap / rug exemption, continuous cue, validated ≤25cm release resolution and unsaved invalid preview. Test multi-obstacle/ceiling constraints; device-test the M0-proven input path. **Implemented + tested:** SAT oriented-box checks, mesh convex-cast on device, ≤25 cm push-out, held unsaved translucent preview with the quiet copy, overlap cue, rug exemption. Device input path depends on M0 manipulation outcome (post-release updates never arrive; re-grab required). **Device defect fixed 2026-10-04:** on the M2 (visionOS 27.0.1, 24M372) “Add” did nothing visible. The app swept the full-size item box against the scan mesh, so every item touched its own floor/wall/table/ceiling and every spot was rejected; M0 run 1 had found and fixed the same thing in the probe only. The shared `OrientedBox.realWorldContactTest` tolerance (4 cm sides/top, 6 cm base) now applies on visionOS and iPhone/iPad LiDAR, with host tests. A failed add now shows its message beside the pressed button. Awaiting device re-test.
- 🟡 E1.S4.T4 Add non-gesture placement/move/rotate/cancel controls; check VoiceOver reachability, Dynamic Type clipping and reduced-motion alternatives in the same demo. **Implemented:** add, move ±10 cm, raise/lower (wall), rotate ±15°, cancel, remove, undo/redo, flip, all as buttons; new items face the user when added, and each floor/table/ceiling item has an in-room 45° turn button (verified drawn in simulator captures; headset check pending); every control has a text label; the UI tests drive the whole flow through accessibility. Device VoiceOver/Dynamic Type/Reduce Motion demo pending.
- 🟡 E1.S4.T5 Record M1 report and component build IDs and contract hash. Demonstrate one actual asset per affinity persisted across a session; no cube-only acceptance. **Simulator:** `testScanPlaceEditRelaunchDelete` places the four real fixtures, relaunches and finds all four. Report: `reports/IMPLEMENTATION-2026-09-23.md`. Device demo pending.

Exit/demo: scan → place all four → move/cancel → save/relaunch → lose alignment/recover → delete, with no older-OS branch or geometry upload.

## 🟡 Epic E2 — M2: anonymous catalogue and reliable offline assets

### ✅ E2.S1 — Versioned API and database

- ✅ E2.S1.T1 Add SQLAlchemy/Alembic tables from plan §6, constraints/indexes, public-read filtering and private operator credentials. Real Postgres tests reject inconsistent tenant/revision/approval rows. **Done 2026-09-23:** 12 tables + tenant seed (Alembic 0001/0002); composite tenant/catalogue FK, CHECKs on states/hashes/prices/currencies, RESTRICT deletes; tests run on a throwaway Postgres 17 cluster.
- ✅ E2.S1.T2 Implement `/v1/catalogues`, assets/filter/search/detail/revision and health routes, stable opaque pagination, structured errors and nullable offers; no user accounts or Design routes. **Done 2026-09-23:** HMAC-signed cursors bound to filters, `{code,message,request_id}` errors (400/404/410/429/503), no duplicates across pages, private/draft assets hidden, revoked revisions 410.
- ✅ E2.S1.T3 Export pinned OpenAPI contract, generate Swift transport models and map to domain; CI detects schema drift and incompatible changes. Add contract round-trip/error decoding tests. **Done 2026-09-23:** `contracts/v1/openapi.json` + in-repo generator → `Kfn8Catalogue/Generated/CatalogueAPI.swift` (contract SHA embedded); `--check` in CI; Swift tests decode real recorded backend responses and map errors.

Acceptance: anonymous clients can see published public assets only; unknown/private/revoked resources have defined errors; v1 schema is reproducible.
Demo: query facets/pages, verify no duplicates, query a private asset, consume same response using generated client.

### 🟡 E2.S2 — Storage, delivery and cache

- ⏸️ E2.S2.T1 Configure smallest fixed App Platform, Managed Postgres and private/public Spaces separation; record actual provisioning/credentials prerequisites. FastAPI never proxies bytes; reject restricted publication. **Blocked on founder:** DigitalOcean account/credentials and spend. Prepared: `ops/app.yaml` (1 × apps-s-1vcpu-0.5gb, no autoscaling), `ops/OPERATIONS.md` provisioning steps; API returns CDN URLs only.
- 🟡 E2.S2.T2 Implement immutable content-addressed/revision-qualified publication and CDN URLs, byte size/hash metadata, conditional writes; verify real Spaces smoke delivery. **Implemented and tested with local storage:** keys `assets/{asset}/r{n}/lod-variant-sha.ext`, `If-None-Match` conditional writes (S3Storage), post-write size/hash verification, idempotent re-publish. Real Spaces/CDN smoke test pending provisioning.
- ✅ E2.S2.T3 Implement streamed downloads/checksum/atomic install, reference-counted revision/LOD pins and unreferenced LRU; test corruption, interrupted downloads, duplicate Designs and insufficient storage. **Done 2026-09-23:** `AssetCache` actor (staging + streaming SHA-256 + atomic rename, size check, pinned set from the repository's reference counts, LRU over unreferenced bytes only, explicit offline-missing and insufficient-storage errors).
- ✅ E2.S2.T4 Implement cursor revocation deltas and client durable apply/cursor advancement; launch/foreground/infrequent opportunity checks, no heartbeat. Test offline behavior, mid-session retention and next-load absence marker. **Done 2026-09-23:** `RevocationSync` applies each deletion before persisting the cursor, 6 h eligibility, launch/foreground triggers; loaded entities are not yanked; next load reports `.revoked` and the Design shows a labelled absence.
- 🟡 E2.S2.T5 Implement verified origin removal/CDN purge for rights revocation; commercial delisting only changes offer metadata. Test deletion/purge partial failures and retry. **Implemented and tested locally:** revocation hides immediately, deletes origin objects, purges, verifies absence, stays `revoking` on partial failure and completes on retry; `delist` only flips offers. DigitalOcean CDN purge untested until provisioning.

Acceptance: saved Design assets remain offline; revoked active scene is not yanked; later load indicates exact missing item without substitution.
Demo: download → disconnect → load → corrupt/recover → rights revoke → reconnect → reload; repeat with commercial delisting to prove difference.

### 🟡 E2.S3 — Operations and end-to-end release pair

- ✅ E2.S3.T1 Enable server request/latency/error/download-volume telemetry without client usage SDK or event endpoint; redact credentials and sensitive payloads. **Done 2026-09-23:** `RequestTelemetry` logs route template, status, latency, bytes, request id; test proves query text, auth headers and IDs never appear. CDN download volume comes from Spaces metrics after provisioning.
- ⏸️ E2.S3.T2 Record baseline + storage/egress estimates; configure billing notification at 125% of estimated total, verify setting without inducing spend. No autoscaling/replicas/worker. **Estimate recorded** in `ops/OPERATIONS.md` (≈US$25/month, alert US$31.25). Alert configuration is a founder action in the DigitalOcean console.
- ⏸️ E2.S3.T3 Run full ingest/publish/generated-client/download/offline/revocation E2E; record monorepo revision if authorised, contract hash and component/deployment build IDs. Do not call local S3 tests a CDN test. **Partial:** ingest→publish→API→revocation E2E passes against real Postgres + local storage; the Swift client decodes the same responses. Deployed E2E blocked on provisioning.

Exit: deployable catalogue + client integration, component build IDs, explicit untaken deployment steps if access is missing.

## 🟡 Epic E3 — M3: compose, compare and inventory

### 🟡 E3.S1 — Saved Designs and ordinary edits

- ✅ E3.S1.T1 Implement name/autosave/duplicate with new IDs and shared revision references; no history/conflict/sync features. Tests prove independence and pin lifetime. **Done 2026-09-23:** every completed edit autosaves; duplicate tested in domain, persistence and UI.
- 🟡 E3.S1.T2 Implement session undo/redo, variant changes and atomic A/B switch after loading; keep old composition until next ready. Test failed loads/edits and explicit update acceptance. **Implemented + tested:** `UndoHistory`, `DesignSwitcher` (keeps current until preload completes, failure keeps current), button and double-tap flip. Simulator E2E `Kfn8UITests` passes on visionOS 27.0 (labelled simulated room); device acceptance pending. Variant UI waits for assets with variants.
- 🟡 E3.S1.T3 Offer asset updates per Design with change summary, never automatic; unavailable-item action can accept a newer revision. Test committed edit/version/pin transition. **Logic done + tested** (`AssetUpdateOffer`); UI appears once remote revisions exist (API not deployed).

Acceptance/demo: duplicate a furnished room, edit five items, flip with gesture and button, cancel invalid placement, undo/redo and relaunch with last committed arrangement.

### 🟡 E3.S2 — Inventory and honest pricing

- ✅ E3.S2.T1 Build default unpriced inventory: quantities/dimensions, no fabricated prices/links, no subtotal if all unpriced. **Done 2026-09-23:** `Inventory.lines`/`subtotals` + app `InventoryPanel`.
- ✅ E3.S2.T2 Build priced path using test-only synthetic offers: independent refresh, dated cached prices, conditional “priced items only”, collapsed/ranged dates, unavailable status, retailer handoff; separate currency totals. **Done 2026-09-23 (logic + tests):** synthetic offers only in tests; per-currency subtotals, same-day collapse, ranges, delisted dated prices excluded from totals. Retailer hand-off link rendering waits for real offers.
- 🟡 E3.S2.T3 Add Swift tests for generic-only/mixed/priced, partial refresh, multi-day dates, currency and delisting combinations. Device demo includes accessibility checks. **Tests done (5 suites);** device accessibility demo pending.

Acceptance: generic-only library reads as a complete inventory, not an error state; no bare stale prices.

### ⏸️ E3.S3 — Conditional still export

- ⏸️ E3.S3.T1 Resolve M0 export outcome before coding. If restricted/unavailable, founder decides re-scope; do not silently mark exported imagery complete or substitute furniture-only render. **Blocked:** the M0 export probe never ran on the headset; the simulator has no ScreenCaptureKit. Founder decision or device run needed.
- ⏸️ E3.S3.T2 If supported, implement explicit home-image consent and local save/share, no watermark/automatic upload; exercise denial/cancel/write failure. **Blocked on E3.S3.T1.** The consent state machine exists in the probe core.
- ⏸️ E3.S3.T3 Open real exported file on device and inspect room+placements; record M3 findings and evidence of zero client analytics/geometry transfer. **Blocked on E3.S3.T1.**

Exit: Designs/inventory acceptance plus actual export evidence or explicit documented scope decision. No portable data export/restore.

## 🟡 Epic E4 — M4: believable rendering under representative load

### 🟡 E4.S1 — Representative assets and realism

- ⏸️ E4.S1.T1 After M0, obtain separate launch-library budget/acquisition decision; secure representative conformed models at real LOD/texture costs. Do not buy assets without that decision. **Blocked on founder budget decision.**
- ⏸️ E4.S1.T2 Verify PBR conversions/material variants/contact shadows/physical lighting/occlusion against source evidence in repeatable room conditions. Fix assets rather than hiding contract violations. **Device + launch library required.** Grounding shadows and environment occlusion are enabled on every placement.
- 🟡 E4.S1.T3 Implement conservative clearance readings, precision/ranges and explicit insufficient-scan guidance. Validate against observed reference distances for engineering QA; no user calibration requirement or fit verdict. **Logic done + tested** (`Clearance`: gaps not verdicts, cm/5 cm rounding, ranges, withheld with rescan hint). Device validation against measured distances pending.

Acceptance: documented real-room comparisons with specific defects resolved; no daylight scrub or production splats.

### 🟡 E4.S2 — M2 performance evidence

- ✅ E4.S2.T1 Instrument frame-time distribution/missed frames/CPU-GPU/memory/texture residency/load times locally; no telemetry upload. **Done 2026-09-23:** `PerformanceMonitor` (RealityKit System deltas, p50/p95/p99/max, drops at 90 Hz, phys_footprint each second, model load times) → local `Documents/perf-*.json`. GPU/texture residency come from Instruments on device.
- ⏸️ E4.S2.T2 Tune measured LOD thresholds/hysteresis, draw calls/texture residency and per-frame allocations with actual representative assets, staying within contract. **Needs representative assets and M2 traces.**
- ⏸️ E4.S2.T3 Run 20 mixed placements + two active virtual lights for 15 continuous minutes walking/turning/entering-leaving view on M2. Report p50/p95/p99/max, spikes, dropped frames and memory; target 90 Hz and zero drops. **Device + launch library required.** `PerformanceTrace.meetsM4Target` refuses simulator traces.
- ⏸️ E4.S2.T4 Record M4 report; if target missed, report measured bottleneck and remediate within agreed requirements, never claim an average-only pass or assume M5 evidence. **Waits for E4.S2.T3.**

Exit/demo: replay named movement route and inspect local traces alongside scene manifest; four repeated low-poly fixtures are not acceptable proof.

## 🟡 Epic E6 — M6: private resumable catalogue production

### ✅ E6.S1 — Durable staged operator ingestion

- ✅ E6.S1.T1 Extend earlier validators/importer into invocation-independent stages with Postgres running/passed/failed records, input fingerprints, tool versions and actionable reports. No queue or hosted worker. **Done 2026-09-23:** `kfn8.ingest.pipeline` stages register/validate/approvals/publish with `ingestion_stage` rows; `kfn8-ingest` CLI.
- ✅ E6.S1.T2 Implement resume/invalidation, per-revision lock and constrained converter subprocess limits; test crash between stages, rerun, changed input and malformed source. **Done 2026-09-23:** passed stages skipped by fingerprint, `pg_advisory_xact_lock` per revision, changed inputs refused (new revision required), converter runs with CPU/file-size/timeout limits and scrubbed env; malformed source fails.
- ✅ E6.S1.T3 Bind separate provenance and visual/dimension approvals to exact revision evidence, approver/time/hash. All assets require both at launch; no sampling reduction yet. **Done 2026-09-23:** approvals carry actor, time, evidence hash and the revision input fingerprint (which excludes the approvals themselves); stale approvals are ignored (tested); all four fixtures carry both approvals and are imported at registration.
- ✅ E6.S1.T4 Exercise private source → conversion/LODs → every-format gate → approvals → immutable publish; failed/rejected/in-review assets never enter public storage. **Done 2026-09-23 (local storage):** test `test_full_operator_flow` and `test_rejection_stops_publication`.

Acceptance/demo: deliberately fail stage, inspect report, correct source, resume, reject missing approval, approve with evidence and publish twice without duplicates.

### 🟡 E6.S2 — Batch readiness and removal evidence

- ✅ E6.S2.T1 Run representative multi-asset batch and capture per-stage timing, failure/pass counts and idempotency results. No enterprise dashboard. **Done 2026-09-23 (4 fixtures):** `ledger/batch-dry-run-2026-09-23.json`: 4/4 validate, 4/4 stop at approvals, 0 public objects, second run skips all passed stages. The ~200-asset batch waits for the launch library.
- 🟡 E6.S2.T2 Verify rights revocation end to end through operator command, origin absence, CDN purge and client next-load state; keep delisting distinct. **Local end-to-end verified;** real CDN purge pending provisioning.
- 🟡 E6.S2.T3 Record backend/client build IDs and authorised monorepo revision if available and approval/validation outputs in M6 report; operator documentation covers retries and credential handling. **Operator docs done** (`ops/OPERATIONS.md`); build IDs and revision wait for an authorised commit and deployment.

Exit: a single operator can build the library reproducibly, with recorded approvals and no tenant auth/feed connector/queue infrastructure.

## 🟡 Epic E7 — M7: TestFlight and MVP1 launch

### ⏸️ E7.S1 — Release candidate and founder demos

- ⏸️ E7.S1.T1 Resolve consumer release name before TestFlight without reopening other deferred §19 decisions; verify signing/app identity/font/asset licences and accurate privacy declarations. **Founder decision (name).** Signing works (team 9L38FSU6M7); font OFL bundled; privacy draft in `release/LIMITATIONS-AND-PRIVACY.md`.
- ⏸️ E7.S1.T2 Integrate complete approved launch library, rerun contract CI and cold-start/first-placement/offline tests; no silent placeholder library. **Blocked on the launch library.**
- ⏸️ E7.S1.T3 Execute complete device E2E: scan/four affinities/manipulation/save/relaunch/recovery/duplicate/A-B/inventory/export-if-supported/delete/download/revocation. Fold three accessibility checks and non-gesture actions into demo. **Device run required.** The simulator E2E equivalents pass.
- ⏸️ E7.S1.T4 Re-run representative performance only if release changes affect it; capture new evidence for any material change. Fix regressions and report failed runs as well as passes. **Waits for M4 device evidence.**

### 🟡 E7.S2 — Distribution and honest release evidence

- ⏸️ E7.S2.T1 Produce signed archive and TestFlight build; founder runs demo and gathers qualitative feedback. No population analytics claims. **Needs release name, App Store Connect record and founder upload approval.**
- 🟡 E7.S2.T2 Publish limitations: M5 untested, no independent accessibility audit, no HA/tested DB restore, no recoverable local backup, best-effort offline revocation. Privacy says no scan upload; no certification claims. **Draft written** (`release/LIMITATIONS-AND-PRIVACY.md`); must be re-checked against the release candidate.
- ⏸️ E7.S2.T3 Verify billing notification and operational health, retain build/contract/repository manifest and rollback deployment instructions. Existing managed backups are not a tested restore claim. **Waits for provisioning.**
- ⏸️ E7.S2.T4 Address blocking TestFlight findings, submit launch build and record actual external review/distribution outcome. Submission is not approval; roadmap stays open until launch outcome exists. **Waits for TestFlight.**

Exit: all prior Epic evidence exists, release is actually distributed, limitations and privacy match shipped behavior. No item is marked ✅ or 🟢 on “should work”.

---

## Track IE — iPhone + iPad client (D7)

> Status legend: ⬜ not started · 🟡 in progress · ✅ done · ⏸️ blocked/deferred · 🟢 verified on-device

Counted separately from the 71 MVP1 tasks. **23 tasks: 2 ⬜ not started · 9 🟡 in progress · 11 ✅ done · 1 ⏸️ blocked/deferred.** Last updated: 2026-09-23 (simulator + host evidence only; no physical iPhone/iPad run yet).

| Epic | Scope | Status |
|---|---|---|
| IE1 | Shared foundation, target and scheme | ✅ |
| IE2 | AR room capture and recovery | 🟡 |
| IE3 | Placement and touch manipulation | 🟡 |
| IE4 | Adaptive iPhone/iPad interface | 🟡 |
| IE5 | Catalogue parity | 🟡 |
| IE6 | Device evidence and distribution | 🟡 |

### ✅ Epic IE1 — Shared foundation, target and scheme

- ✅ IE1.T1 Add iOS 27 to `Kfn8Kit` platforms; Domain/Persistence/Catalogue compile for iOS unchanged; host tests still pass. **Done 2026-09-23:** `.iOS("27.0")` added; 65/65 package tests pass on the host (new: `poseInFrontFacesTheViewer`, `scanDataReadsBackTheCurrentScanAndRejectsTampering`).
- ✅ IE1.T2 Split app sources into shared (`Kfn8/Shared`) and platform (`Kfn8/visionOS`, `Kfn8/iOS`) folders; move reusable room/placement logic (scan snapshot, frame derivation, room-local surfaces, simulated room, placement entity sync, pose in front of the viewer) out of visionOS-only files. visionOS behaviour unchanged: device + simulator builds and all three visionOS UI tests pass. **Done 2026-09-23:** `Kfn8/Shared` (app model + launch, catalogue, theme, main window + panels, `PlacementScene`, `CapturedPlanes`, `SimulatedRoom`, `TurnHandle`), `Kfn8/visionOS`, `Kfn8/iOS`; `RoomFrame.poseInFront` moved into Kfn8Domain. visionOS device + simulator builds and all three visionOS UI tests pass after the split.
- ✅ IE1.T3 `Kfn8iOS` target and scheme in `project.yml`: iOS 27.0, iPhone + iPad, bundle `com.appliaison.kfn8.ios`, Swift 6 strict concurrency, warnings as errors, camera usage text, fonts, bundled catalogue, app icon. Builds for iOS device and simulator SDKs. **Done 2026-09-23:** `Kfn8iOS` + `Kfn8iOSUITests` targets and scheme; flattened 1024 px icon generated by `tools/make_app_icon.py`; unsigned device and simulator builds pass with warnings as errors.
- ✅ IE1.T4 `tools/ci.sh` builds the iOS app (device + simulator SDK) and, with `--with-ui`, runs the iOS UI tests. **Done 2026-09-23:** CI now 15 steps; `ci.sh --with-ui` passed end to end (visionOS 3 tests, iPhone 18 Pro, iPad Pro 11-inch). [report](reports/IMPLEMENTATION-2026-09-23.md#addendum-d7-iphone--ipad-client)

### 🟡 Epic IE2 — AR room capture and recovery

- 🟡 IE2.T1 `ARRoomSession`: world tracking with horizontal + vertical plane detection and classification (floor, wall, ceiling, table, seat); room frame derived from floor + largest wall with the shared rules; camera permission with a plain-language denial message. **Implemented:** `ARRoomSession` (plane classification → `CapturedPlanes`, frame on floor + widest wall, room anchor), camera-permission copy for denied/restricted. Needs a physical iPhone/iPad (IE6.T2).
- 🟡 IE2.T2 Real-geometry collisions: LiDAR scene-reconstruction mesh when supported; on non-LiDAR devices, classified plane boxes only, stated in the UI. No silent fallback. **Implemented:** LiDAR `sceneReconstruction = .mesh` + RealityKit scene-understanding collision (convex cast against `.sceneUnderstanding`); non-LiDAR devices show “No depth sensor: only floors, walls, tables and seats are checked for collisions.” Device check pending.
- 🟡 IE2.T3 Return visits: save an `ARWorldMap` with the scan (local only, excluded from backup), relocalize with bounded guided attempts, keep content hidden until verified; rescan into the same Room or review contents. **Implemented:** world map archived inside the room's scan file (removed with the room; excluded from backup); new `DesignRepository.scanData(for:)` with checksum; relocalization in bounded 8 s attempts; fresh map saved on leaving. Device check pending.
- 🟡 IE2.T4 Coaching: `ARCoachingOverlayView` plus the shared status text while scanning. **Implemented:** `ARCoachingOverlayView` (tracking goal) plus the shared status line. Device check pending.
- ✅ IE2.T5 Labelled simulated room on the iOS simulator (ARKit is unavailable there), shared with visionOS. **Done 2026-09-23:** shared `SimulatedRoom`; the iOS simulator draws its floor/wall faintly and labels “simulated room (simulator only)”; iPhone and iPad E2E pass.

### 🟡 Epic IE3 — Placement and touch manipulation

- ✅ IE3.T1 Shared placement-scene sync renders committed Designs + previews in `ARView` (model cache, grounding shadows, translucent held-invalid preview, overlap cue). **Done 2026-09-23 (simulator):** shared `PlacementScene` renders all four fixtures in `ARView`; iPhone and iPad E2E pass.
- 🟡 IE3.T2 Touch: one-finger drag and two-finger rotate (no scaling) feed the shared release pipeline (attach → real collision → ≤25 cm resolution → commit, or held unsaved with Cancel). **Implemented:** pan on the item's support plane (wall plane for wall items) and two-finger twist about +Y feed `dragUpdated`/`release`/`cancel`; tap selects, double-tap flips. Not exercised by the UI tests; device touch check pending.
- 🟡 IE3.T3 On-screen turn button beside each placed item (screen-projected), plus the shared non-gesture move/rotate/cancel/remove controls. **Implemented:** screen-projected 48 pt turn button per item (45° clockwise, Undo-able), VoiceOver label “Turn <item> 45 degrees”; its presence is asserted in the iPhone/iPad E2E, a tap is not yet.
- 🟡 IE3.T4 Occlusion: scene-depth occlusion on LiDAR devices and people occlusion where supported. **Implemented:** scene-understanding occlusion on LiDAR devices, `personSegmentationWithDepth` where supported. Device-only.
- ✅ IE3.T5 New items placed in front of the camera, facing the viewer, at a distance suited to a handheld screen. **Done 2026-09-23:** 1.5 m ahead of the camera, facing the viewer (shared `RoomFrame.poseInFront`, unit-tested).

### 🟡 Epic IE4 — Adaptive iPhone/iPad interface

- ✅ IE4.T1 Reuse the shared sidebar, Design, Inventory and Catalogue panels in a `NavigationSplitView` (iPad: sidebar + detail; iPhone: stack). **Done 2026-09-23:** shared `MainWindow` with `RoomViewActions`; iPhone collapses to one column and opens the room detail on selection; iPhone and iPad E2E pass.
- ✅ IE4.T2 Full-screen AR room screen with a resizable bottom sheet holding the same panels; Leave button; banners for recovery and errors. **Done 2026-09-23 (simulator):** full-screen AR room with status bar, Leave and panel toggle; panel is an inspector (iPad column / iPhone sheet capped at 78% so the bar stays reachable, drops to half height after adding).
- 🟡 IE4.T3 Item preview sheet (orbitable 3D, real W×D×H) replacing the visionOS volume. **Implemented:** `PreviewSheet` (same `PreviewFit`, orbit camera, real dimensions). Not yet covered by a UI test.
- 🟡 IE4.T4 Accessibility: VoiceOver labels on every control and in-scene button, Dynamic Type up to accessibility sizes without clipping, Reduce Motion respected. **Partly:** every control and in-scene turn button has a text/VoiceOver label; Dynamic Type layouts use the shared single-column rule. VoiceOver/Dynamic Type/Reduce Motion device check pending.

### 🟡 Epic IE5 — Catalogue parity

- ✅ IE5.T1 Bundled catalogue (four approved fixtures) loads and places on iOS. **Done 2026-09-23 (simulator):** all four bundled approved fixtures load and place on iPhone and iPad.
- ⏸️ IE5.T2 Remote catalogue (same `RemoteCatalogue`, cache, revocation) configured via `Kfn8APIBaseURL` / `--api`; verified once the backend is deployed (E2.S2 dependency). **Blocked:** same code path as visionOS; waits for the backend deployment (E2.S2 provisioning).

### 🟡 Epic IE6 — Device evidence and distribution

- ✅ IE6.T1 iOS simulator end-to-end UI tests: create space/room → simulated scan → place all four → move/rotate/undo → relaunch → delete. **Done 2026-09-23:** `Kfn8iOSEndToEndTests.testScanPlaceEditRelaunchDelete` passes on iPhone 18 Pro and iPad Pro 11-inch (iOS 27.0 simulators). Simulator evidence only. [report](reports/IMPLEMENTATION-2026-09-23.md#addendum-d7-iphone--ipad-client)
- ⬜ IE6.T2 Physical iPhone (LiDAR and non-LiDAR if available) and iPad run: scan, place, occlusion, relocalization; screenshots and findings in `reports/`.
- ⬜ IE6.T3 Signed archive and TestFlight for iOS; privacy declarations match the shipped behaviour (camera, no upload). Needs founder approval.
