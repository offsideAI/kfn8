# iOS I0.S1 foundation, 2026-10-05

Host and simulator evidence only; nothing here is device evidence. Toolchain: Xcode 27.0 (27A266a), iOS 27.0 SDK and simulators, Swift 6 strict concurrency with warnings as errors.

## Built

- **Project (I0.S1.T2):** `_Kfn8-frontend-ios-src/project.yml` (xcodegen) generates `Kfn8iOS.xcodeproj` (ignored by Git).
  - Targets: the `Kfn8iOS` app and `Kfn8iOSUITests`.
  - App settings: iOS 27.0, iPhone + iPad, team 9L38FSU6M7, working bundle ID `com.appliaison.kfn8.ios` (ID-1).
  - Tooling: `setup.sh` checks Xcode 27, the iOS 27 SDK and xcodegen, and asks before opening Xcode. A README is included.
- **Kfn8Kit copy (I0.S1.T3):** `Packages/Kfn8Kit`, copied from the Vision Pro Kfn8Kit, with platforms set to iOS 27 plus the macOS host and its origin recorded in its README. New `BundledCatalogue` reader: it decodes contract-v1 manifests, checks the LOD0 USDZ's size and SHA-256 before offering it, and derives stable revision IDs. It has 5 new tests.
- **Bundle (I0.S1.T4):**
  - the nine conformed fixtures (LOD0 USDZ and manifest each);
  - Fraunces and Hanken Grotesk with their OFL texts;
  - the app icon from `tools/make_app_icon.py --ios-catalog`: opaque 1024 × 1024 RGB, with the visionOS layers written to scratch so the Vision Pro catalog was untouched.
- **CI (I0.S1.T5):** `tools/ci-ios.sh [--with-ui]`. `generate_swift_client.py` gained `--out`, so the iOS copy's transport models are drift-checked against `contracts/v1/openapi.json`. The UI-test steps fail unless the result bundle reports at least one executed test and no failures.
- **Simulated room (I0.S1.T6, partial):** `RoomCaptureMode` picks the mode from what ARKit reports at runtime: "Simulated room (simulator only)", "Camera and depth sensor", or "Camera only" with the no-depth-sensor notice. `SimulatedRoom` defines the floor, wall, ceiling and table obstacle. The label is shown and tested. Drawing the room comes with the AR room view (I1.S5.T2).
- **First screen:** the room-capture mode and the verified built-in catalogue (name, category · affinity, W × D × H, licence · author). It says plainly that scanning and placement aren't in this build yet. It's marked `TODO(kfn8-ios)`, to be replaced by I1.S5.

## Verification actually run

| Check | Result |
|---|---|
| `generate_swift_client.py --check` (Vision Pro copy and, with `--out`, the iOS copy) | Both up to date |
| `kfn8-validate --bundle` on the iOS bundle | 9/9 PASS |
| Kfn8Kit host tests (iOS copy) | 72/72 pass (the 67 copied plus 5 bundled-catalogue tests) |
| `Kfn8iOS` build, iOS device and simulator SDKs, unsigned | Succeeded, no warnings |
| `tools/ci-ios.sh --with-ui` | PASSED. UI test `testLaunchShowsSimulatedRoomAndBuiltInCatalogue`: 1/1 on iPhone 18 Pro and 1/1 on iPad Pro 11-inch (M5), confirmed from the xcresult summaries |
| Vision Pro app after removing the D7 target | Project regenerates; Kfn8Kit 67/67; device and simulator builds succeed; visionOS UI tests 4/4 |

## Not done

- **I0.S1.T6:** the simulated room isn't drawn yet. That needs the AR room view (I1.S5.T2).
- **Device runs:** none yet. These are I0.S2 on the iPhone 13 Pro Max.
