# M0 findings — readiness only, milestone incomplete

Date: 2026-09-19, amended 2026-09-22. Status: **Signed probe installed on the M2 (visionOS 27.0); no device gates executed yet.**

## Implemented

- Created TECHNICAL-PLAN.md and ROADMAP.md from interview Q1–Q55; updated PRD v0.3 and SALIENT-NOTES. Seven Epics map exactly to M0, M1, M2, M3, M4, M6, M7. Routine approval stops removed; actual feasibility/dependency gates preserved.
- Implemented read-only `tools/check_m0_readiness.py`, explicit DEVELOPER_DIR, JSON command evidence and nonzero exit on missing/incorrect toolchain, licence errors and timeouts. Never accepts legal terms, changes xcode-select, or calls tooling readiness a device pass.
- Eight tests first failed because implementation was absent, then all eight passed. Tests cover wrong SDK, simulator-only SDK, old Swift, licence refusal, missing executable, timeout, explicit CLI argument and successful toolchain with device still unverified.

## Real environment evidence

Global selected developer path: `/Users/coder/Developer/Xcode/Xcode_26_5_0/Xcode_26_5_0.app/Contents/Developer`. Its SDK listing contains xros26.5 and xrsimulator26.5. No 26 fallback was built.

Separate installation: `/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer`.

- `xcodebuild -version`: exit 0, Xcode 27.0, build 27A266a.
- `xcodebuild -showsdks` under that DEVELOPER_DIR: exit 69, “You have not agreed to the Xcode license agreements.”
- Real readiness CLI: exit 1, `status=blocked`, `m0_passed=false`.
- Full raw output is in [M0-READINESS.json](M0-READINESS.json). Sandbox filesystem/cache warnings are retained alongside the specific licence failure rather than hidden.

This is environment readiness, not a platform-quality failure and not grounds for changing D1. The founder must review/accept the agreement. No licence acceptance, downloads, model preparation, paid provisioning or device evidence was fabricated.

## Actual feature measurements

| Probe | Result | Measurement |
|---|---|---|
| Physical space lighting | Not run | None |
| Environment Occlusion | Not run | None |
| ManipulationComponent / invalid-release continuation | Not run | None |
| Passthrough export file | Not run | None |
| One-attempt splat | Not attempted | None; budget not consumed |
| 20-placement / 2-light / 15-minute M2 performance | Not run; M4 dependency | None |

No frame rate, memory, lighting, occlusion or visual-quality pass is claimed. No M1 or later implementation has started.

## Reproduce / unblock

1. Open `/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app` and review/accept its licence yourself; complete prompted first-launch setup. Do not switch to 26 as a workaround.
2. From the client repository run:

```sh
python3 -m unittest discover -s tests -v
python3 tools/check_m0_readiness.py --developer-dir /Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer
```

3. Expected after setup: exit 0 with `toolchain_ready_device_unverified`. This is not an M0 pass. Next verify signing and M2 pairing, implement exact SDK-backed probes, then run founder-operated on-device demos.
4. Record physical test OS/build, expected/observed behavior, traces and permitted captures. Unresolved failure after the one short obvious-setup check stops dependent implementation; splat/export findings remain separately nonblocking for M0.

## Plan deviations

The previous conversation announced but did not create TECHNICAL-PLAN.md. It was created in this execution before roadmap decomposition. Xcode 27 was present in a separate directory despite 26.5 being selected; the actual blocker is licence acceptance. No SDK downgrade or speculative rendering code was introduced.

## Repository housekeeping amendment

The founder superseded separate repositories with the parent `kfn8` monorepo. Nested client `.git` was removed on explicit instruction. Historical nested commit IDs are no longer resolvable here and do not identify parent revisions. Root ignore rules now cover Swift/Xcode and Python artifacts; source assets and evidence are retained. No Git commands were run during housekeeping. M0 device status is unchanged.

## 2026-09-22 re-check

Global `xcode-select -p` now reports `/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer` (the founder switched it; no agent changed it). Readiness CLI run with explicit `--developer-dir` for Xcode 27:

- `xcodebuild -version`: exit 0, Xcode 27.0, build 27A266a.
- `xcodebuild -showsdks`: exit 0; lists `xros27.0` and `xrsimulator27.0`.
- `xcrun swift --version`: exit 0, Apple Swift 6.4.
- CLI exit 0, `status=toolchain_ready_device_unverified`, `m0_passed=false`. Raw output: [M0-READINESS-2026-09-22.json](M0-READINESS-2026-09-22.json). The 2026-09-19 blocked run is retained in [M0-READINESS.json](M0-READINESS.json).
- Unit tests: 8 passed.

This closes the licence blocker only. Signing, M2 pairing, the nonshipping probe target and all three blocking capability measurements remain outstanding. The source directory is still `_Kfn8-frontent-avp-src` (empty, original spelling); the backend directory is still empty.

## 2026-09-22 implementation (E0.S1.T4, E0.S2.T1, E0.S2.T2, E0.S3.T2)

### What was built

- Source directory: the empty misspelled `_Kfn8-frontent-avp-src` was renamed to `_Kfn8-frontend-avp-src` (the founder's stated intent; the directory was empty, so no content moved).
- `project.yml` (xcodegen 2.45.4) generates `Kfn8.xcodeproj` with one nonshipping target `Kfn8M0Probe`: visionOS 27.0 deployment target, `SUPPORTED_PLATFORMS = xros xrsimulator`, Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`, warnings as errors, existential-any upcoming feature. No iOS target. Bundle ID `com.appliaison.kfn8.m0probe`. Entitlements are empty; Info.plist declares `NSWorldSensingUsageDescription` and `NSPhotoLibraryAddUsageDescription` only.
- Local package `Kfn8M0ProbeCore` (pure Swift, no RealityKit/ARKit): probe catalogue with SDK symbol citations, `AttachmentAffinity`/`AttachmentResolver` (floor/tabletop drop to support; wall/ceiling orient to surface normal, gravity suppressed), `ReleaseResolver` (shortest-axis push-out then validated candidates within 25 cm, otherwise unresolved), `ManipulationProbeState` (begin/update/release/end/hand-off transcript, held-invalid state with the plan's quiet copy, cancel restores committed or removes new, counter for transform updates after release without a new begin), lighting/occlusion/export state machines (export cannot start without consent), `FrameTimeStatistics` (p50/p95/p99/max, drops against 90 Hz) and `EvidenceLog` (JSON, simulator records never count as device evidence, blocking gate requires all three latest device outcomes passed).
- App: window with every control (non-gesture path for placement, nudge, cancel, lighting, occlusion, export, evidence), and a Mixed Immersive Space with four fixtures (floor block with a brass lamp, wall block, ceiling block, tabletop block; base-centre pivots; `ManipulationComponent` with `releaseBehavior = .stay` and scaling disabled), an occlusion cube with `EnvironmentBlendingComponent`, ARKit plane detection feeding the attachment resolver, ARKit scene reconstruction feeding collision-only mesh entities (no model, so they cannot occlude), `convexCast` validation of released poses against those meshes, a translucent cue while intersecting or held invalid, `ManipulationEvents` subscriptions driving the state machine, a RealityKit `System` sampling `deltaTime` into the statistics, and a ScreenCaptureKit picker/stream export path that writes the first frame as PNG into Documents after explicit consent.

### Verification actually run

| Check | Command | Result |
|---|---|---|
| Package tests, host | `xcrun swift test` in `Packages/Kfn8M0ProbeCore` (Xcode 27 toolchain) | 41 tests in 9 suites passed. An earlier run had 1 failure (`jsonRoundTrip`: ISO 8601 encoding drops sub-second precision); the test fixture now uses a whole-second timestamp. |
| Device SDK compile | `xcodebuild … -destination 'generic/platform=visionOS' CODE_SIGNING_ALLOWED=NO build` | BUILD SUCCEEDED |
| Simulator SDK compile | `xcodebuild … -destination 'generic/platform=visionOS Simulator' CODE_SIGNING_ALLOWED=NO build` | BUILD SUCCEEDED |
| Package tests via scheme on visionOS 27.0 simulator | `xcodebuild … -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0' test` | final run: `Test run with 41 tests in 9 suites passed`, `** TEST SUCCEEDED **` (visionOS 27.0 simulator, 15:39 local). The first run had printed TEST FAILED only because the result bundle could not be saved under the sandboxed temp directory; rerun with `TMPDIR` in the scratchpad and `-resultBundlePath` fixed that. |
| Signed device build | `xcodebuild … -destination 'generic/platform=visionOS' -allowProvisioningUpdates build` | FAILED: “No Account for Team G7Y435RZV6” and, with the certificate's team, “No Account for Team G4Y5TXVX4P”; no provisioning profile for `com.appliaison.kfn8.m0probe` |
| Paired devices | `xcrun devicectl list devices` | one iPhone and one Apple TV paired; Apple Vision Pro appears only as a simulator |

Compile fixes made along the way, all against the real SDK: `PlaneAnchor.classification` is deprecated since visionOS 26.0 (use `surfaceClassification`); `SpotLightComponent.Shadow` is a separate component, not a property; light initialisers take `UIColor` on visionOS; ScreenCaptureKit is absent from the simulator SDK.

### Not done, reported explicitly

- No physical-device run. Every probe outcome in the evidence log is `notRun`.
- Volume-to-room hand-off (part of E0.S2.T5's scope) is not in the probe. It needs a volumetric window and is recorded here as TODO(kfn8) rather than claimed.
- Hard real-world collision uses ARKit mesh anchors; ceiling-height constraints and multi-obstacle cases are exercised only by the resolver's unit tests.
- The export probe proves only that a frame can be written; whether it contains passthrough pixels is the device question.

### Founder actions required

1. In Xcode 27: Settings → Accounts, sign in with the Apple Developer account that owns team G4Y5TXVX4P (the only Apple Development certificate on this Mac) or add the team that should own MVP1 and tell me which; then let automatic signing create the development profile for `com.appliaison.kfn8.m0probe`.
2. Pair the M2 Vision Pro with this Mac (Settings → General → Remote Devices on the headset) and enable Developer Mode.
3. Run the device protocol in `_Kfn8-frontend-avp-src/README.md` and return `M0-EVIDENCE.json` plus screenshots.

## 2026-09-22 simulator smoke run (not device evidence)

The founder signed into Xcode 27 and asked for the simulator while the M2 charges. Runs used the visionOS 27.0 simulator (runtime 24M362, device 1488D996-9698-4DCE-BA35-D31F8492C701) with `xcrun simctl install/launch` and the launch arguments `--open-immersive --lamp-on` (optionally `--occlusion-default`). Screenshots: [window](evidence/2026-09-22-simulator-window.png), [immersive space with fixtures and frame readout](evidence/2026-09-22-simulator-immersive.png).

Observed:

- App launches, the control window renders every section, no crash; the only log errors are the simulator's usual XPC/backlight noise.
- The Mixed Immersive Space opens; ceiling and wall fixtures, lamp post and bulb are visible. The floor block and occlusion cube are hidden behind the simulated sofa and coffee table from the default viewpoint, so the occluded-versus-default comparison is inconclusive on the simulator.
- ARKit reports `unsupported on this device/simulator`, so no planes, no mesh anchors, no attachment or collision validation. Export is unavailable (no ScreenCaptureKit in the simulator SDK).
- Frame-time sampling works (first delta 11.11 ms). The simulator renders on demand when the scene is static, so the readout after 15 s was n=110 with p50 155.56 ms and 68 drops. That is simulator scheduling, not a renderer measurement.

Defects the simulator run exposed, all fixed and re-verified (device SDK compile succeeded, 41 package tests pass):

1. xcodegen regenerates `Info.plist` from `project.yml`, which wiped the hand-written scene manifest; the immersive space refused to open (“does not support multiple scenes”). The keys now live in `project.yml` under `info.properties`.
2. `FrameTimeSystem.registerSystem()` was called inside the RealityView closure, after the scene existed, so the system never ran. Registration moved to the App initializer.
3. The frame-time row did not refresh; it now uses a one-second `TimelineView` reading the live statistics.

Signing after the founder's sign-in: `xcodebuild -allowProvisioningUpdates` still reports “No Account for Team” for G4Y5TXVX4P and G7Y435RZV6. Xcode has exactly one Apple ID stored; its team ID is not either of those. The founder needs to read the Team ID from Xcode → Settings → Accounts and it will be set as `DEVELOPMENT_TEAM` in `project.yml`.

## 2026-09-22 evening: device readiness

- Headset `App's Apple Vision Pro` (RealityDevice14,1, UDID 00008112-000979EA1A21A01E): paired (local network), Developer Mode enabled, OS 27.0 build 24M362 after the founder's update.
- Earlier failure “The developer disk image could not be mounted” (CoreDeviceError 12040) was caused by a missing `xrOS_DDI.dmg` under `/Library/Developer/CoreDevice/CandidateDDIs/` while the headset was still on 26.5. After the update Xcode staged the image; `xcrun devicectl device info ddiServices` now reports `buildUpdate 27A266a, contentIsCompatible true`.
- Signing resolved: Xcode's stored team list for the signed-in account shows OffsideAI Inc. (9L38FSU6M7, company) and a personal team (Q73A225H22). With `DEVELOPMENT_TEAM=9L38FSU6M7 -allowProvisioningUpdates` the device build succeeds (identity `Apple Development: Arunabh Das (G4Y5TXVX4P)`, automatic team profile). `project.yml` now carries that team.
- Deployment verified: `xcrun devicectl device install app` installed `com.appliaison.kfn8.m0probe` 0.0.1 into `/private/var/containers/Bundle/Application/481A3D49-…/Kfn8M0Probe.app`; the headset lists “Kfn8 M0 Probe”. Not launched by the agent; the founder runs the protocol.
- E0.S1 acceptance met. M0 status is now: probe deployed, all five probe outcomes still `notRun`.

## 2026-09-22 first device run and the lighting setup check (budget now used)

Founder ran the protocol once (17:35–17:41) without pressing Record, then reported for the lighting probe: “Nothing changes” when toggling the lamp. Device screenshot of the window before the immersive space: [evidence/2026-09-22-device-01-environment.png](evidence/2026-09-22-device-01-environment.png). The room was dark (TV showing “No Signal”, unlit desk).

The single short obvious-setup investigation allowed by the M0 rules was spent on lighting. Findings, all from the SDK and Apple's WWDC26 session “Explore advances in RealityKit”, not from guesses:

1. API usage matched Apple's example exactly (`entity.components.set(SpotLightComponent.SurroundingsLight())` on the light entity; point lights equally supported).
2. Probe defect: the lamp defaulted to 2000 intensity units, about 13× dimmer than the SDK's own point-light default of 26963.76. Fixed: default 27000, attenuation radius 6 m, slider up to 100000.
3. Apple states the effect projects onto “RealityKit's scene understanding mesh”. The probe ran ARKit providers for placement but never started RealityKit's `SpatialTrackingSession`. Fixed: the immersive view now runs `SpatialTrackingSession(tracking: [.world, .plane], sceneUnderstanding: [.collision, .physics])` and records unavailable capabilities in the evidence notes and window.
4. Diagnostic added: a bone virtual panel 45 cm behind the lamp (toggle in the window) and a “Lamp components” readout listing which light components are on the entity and whether it is in the scene. Every lamp toggle now writes a note with intensity, components, surface counts and scene-understanding status.
5. Environmental factor: the dark room can starve scene understanding. Retest requires normal room lighting.

If the retest with these fixes still shows no light on real surfaces while the virtual panel is lit, that is a platform-quality finding for the founder's decision (options: accept lighting only on virtual geometry, or reopen D1). No further investigation is authorised.

## 2026-09-22 device runs 2 and 3: first recorded outcomes

Evidence files: [run 2](evidence/2026-09-22-device-M0-EVIDENCE-run2.json) (automatic notes only), [run 3](evidence/2026-09-22-device-M0-EVIDENCE-run3.json) (two recorded outcomes). Device RealityDevice14,1, visionOS 27.0 (24M362), not simulator. Room lit; 7–11 planes and 8 mesh anchors detected; RealityKit `SpatialTrackingSession` running with all requested capabilities.

| Probe | Recorded outcome | Evidence |
|---|---|---|
| Physical space lighting | **passed** (founder, 22:27:48 UTC) | Chips: real floor brightened, real wall brightened, virtual panel brightened. Point light, `PointLight + PointLight.SurroundingsLight` in scene, intensity 12000–98000 across toggles, on/off notes matched. Founder's chat remark: distribution on real surfaces is uneven or jagged (consistent with projection onto the coarse 8-anchor scene mesh). Screenshots on/off not yet received. |
| Environment occlusion | **failed** (founder, 22:31:19 UTC), clarification pending | Record was made while the mode read `defaultBlending`; chips: cube drew through furniture, default mode drew on top as expected, edges clean while still. Whether the cube was hidden in the OCCLUDED mode is not established by the record. The window now labels the mode under test unmistakably; retest requested. |
| ManipulationComponent | not recorded | Transcript across 9 releases on floor/wall/tabletop: `updatesAfterReleaseWithoutBegin` = 0 every time, so the platform delivers no transform updates after `WillRelease`; continuation without re-grab is not a platform behaviour. Inputs seen: indirectPinch only. Wall fixture: 3 of 4 releases unresolved, traced to a probe defect (pivot placed on the wall plane, block straddling the wall mesh); fixed by mounting wall items by their back face. |
| Export | not attempted | Blocked by the scrolling problem below. |

Frame times while lit and manipulating: p50 11.1 ms, p95 11.1 ms, p99 22.2 ms, max 89–133 ms, 1.3–1.6 % dropped frames over 36k–43k samples. Informational only at M0.

Usability defect found on device: the founder could not scroll the control window while the immersive space was open, because fixtures spawned on the window's line of sight and captured gaze. Fixed by paging the window (Setup / Light / Occlude / Move / Export / Evidence) so nothing needs scrolling, moving spawn positions off-centre and 2 m out, and shrinking the virtual test panel. Observation chips replaced free-text fields so no typing is required in the headset.

## 2026-09-23 occlusion run 4 and setup check (occlusion budget now used)

Evidence: [run 4](evidence/2026-09-23-device-M0-EVIDENCE-run4.json). Founder recorded **inconclusive** in `occludedBySurroundings` mode with chips “cube drew through furniture”, “default mode drew on top as expected”, “edges clean while still”. Scene understanding running; 5–12 planes, 6 mesh anchors.

Obvious-setup check: the transcript shows four drags of the small clay **tabletop** fixture and none of the occlusion cube is logged (cube drags are not transcribed). Both were clay-coloured and only the cube carried `EnvironmentBlendingComponent`, so the object behind the furniture was very likely the non-occluded tabletop block. Fix: the occlusion cube is now bone-white and 50 cm, and every fixture carries the same occlusion setting as the shipping app. No further investigation is authorised; the next recorded result stands as the occlusion outcome.

## 2026-09-23 occlusion outcome: PASSED (founder-confirmed)

Evidence: [run 5](evidence/2026-09-23-device-M0-EVIDENCE-run5.json), M2 Vision Pro, visionOS 27.0 (24M362), not simulator; scene understanding running, 10 planes, 8 mesh anchors. In this build every fixture carries `EnvironmentBlendingComponent(.occluded(by: .surroundings))`, the same setting as the shipping app. The founder dragged the clay tabletop block behind real furniture in occluded mode and selected “Furniture hid the cube” and “Edges clean while still”. The button tapped was “Record: failed”, which contradicted those chips; asked directly, the founder confirmed that the furniture hid the part of the block behind it. The outcome is recorded as **passed** on that confirmation. Not separately recorded: edge behaviour while walking and turning (the “lag or flicker while moving” chip was not selected). Frames during the run: p50 11.1 ms, p99 33.3 ms, 482 dropped of 19 344 (informational; M4 owns performance).

## 2026-09-23 manipulation decision D6 and M0 blocking-gate status

Evidence from every M2 run: `updatesAfterReleaseWithoutBegin = 0` across all releases (runs 2–5), so visionOS 27 delivers no input after `WillRelease`; continuation without re-grab is not possible. Options put to the founder: (1) keep the item where dropped, translucent and unsaved, re-pinch or Cancel, which is already implemented; (2) automatic snap-back to the last valid pose, which contradicts “no distant jump”. **Founder chose option 1 (decision D6).**

Blocking gates on the M2: physical space lighting **passed**, Environment Occlusion **passed**, ManipulationComponent **passed with D6** (indirect pinch, `.stay`, held and valid releases observed; direct grab, ceiling and volume hand-off move to the M1 device demo). M1 may proceed on platform grounds. The nonblocking export probe has still not run.
