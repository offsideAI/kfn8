# iOS I0.S2 findings: platform feasibility

Status: **probe built and simulator-checked; no device runs yet.** Every result below the "Device results" heading must come from a physical iPhone or iPad, with model, iOS version and build.

## T1: SDK API evidence (done 2026-10-05)

See [IOS-SDK-API-EVIDENCE.md](IOS-SDK-API-EVIDENCE.md).

- **Stack:** ARKit `ARSession` + RealityKit `ARView`. `SpatialTrackingSession` has no world-map persistence, so it can't relocalize a room.
- **ID-3 (lighting):** `PointLightComponent.SurroundingsLight` and `SpotLightComponent.SurroundingsLight` are `@available(iOS, unavailable)`. The iOS candidate is the LiDAR room mesh with `SceneUnderstanding.Options.receivesLighting`. It's LiDAR-only and unproven on a device.

## T2: Probe (done 2026-10-05)

- **App:** `_Kfn8-frontend-ios-src/Kfn8iOSProbe` ("Kfn8 Probe", `com.appliaison.kfn8.ios.probe`, nonshipping). It has seven pages: Setup, Find, Collide, Occlude, Light, Photo and Evidence.
- **Recording:** chips plus Record passed/failed/inconclusive, with automatic context saved to `Documents/IOS-PROBE-EVIDENCE.json` after every record. The file keeps records across relaunches on the same device and build, because the relocalization test needs a relaunch.
- **Core:** `Packages/Kfn8iOSProbeCore` holds the evidence log (simulator records never count), the bounded 30 s relocalization attempt and the consent-gated photo flow. It has 10 Swift Testing tests on the host.
- **Collision:** the Collide page sweeps the box against the room mesh twice, with `OrientedBox.realWorldContactTest` and at full size, so the device evidence shows whether the tolerance is needed on iPhone too.
- **Never red:** a blocked box turns translucent.
- **Fixed during the simulator smoke test:** the first version used a seven-segment picker. On an iPhone its labels truncated ("Occl…", "Evide…") and a page switch didn't register. It's now a scrollable row of full-label page buttons that VoiceOver announces as selected.

Verification run on 2026-10-05:

| Check | Result |
|---|---|
| `Kfn8iOSProbeCore` host tests | 10/10 |
| Probe build, iOS device and simulator SDKs, unsigned | Succeeded, no warnings (deprecated `UIRequiresFullScreen` avoided by supporting every orientation) |
| Probe smoke test on the iPhone 18 Pro simulator | 1/1: launches, says "World tracking isn't supported here (simulator)", every page opens, capture stays disabled without consent |
| `tools/ci-ios.sh --with-ui` | PASSED, 11 steps |

## Probe defect fixed before any device run (2026-10-06)

The app's simulator photo test crashed with a Swift 6 isolation trap: the block passed to `PHPhotoLibrary.performChanges` was written inside main-actor code, so it was isolated to the main actor, but Photos runs it on its own queue (`_dispatch_assert_queue_fail` in `swift_task_isCurrentExecutor`). The probe's Photo page had the same code and would have crashed at T6 on the phone. Fixed in both the app and the probe:
- the Photos change runs in a `nonisolated` helper;
- ARKit's `getCurrentWorldMap` completion (probe Save room map) is wrapped the same way;
- `ARView.snapshot` callbacks are `@Sendable`.

Install a fresh probe build before running the protocol.

## Device results

Pending: T3 relocalization, T4 collision and occlusion, T5 lighting, T6 room photo. Device: iPhone 13 Pro Max (iPhone14,3), iOS 27.0 (24A5355q), LiDAR. The founder runs the protocol in `_Kfn8-frontend-ios-src/README.md` and the agent pulls `IOS-PROBE-EVIDENCE.json`.
