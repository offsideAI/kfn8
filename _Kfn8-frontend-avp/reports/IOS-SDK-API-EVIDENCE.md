# iOS 27 SDK API evidence (I0.S2.T1), 2026-10-05

Read from the installed SDK only: Xcode 27.0, `iPhoneOS27.0.sdk`, under `/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`. Paths below are relative to its `System/Library/Frameworks`. Nothing here is device evidence. Every capability is confirmed on a phone in I0.S2.T3–T6.

## Decision: ARKit `ARSession` + RealityKit `ARView`

| Need | `ARSession` + `ARView` | `RealityView` + `SpatialTrackingSession` |
|---|---|---|
| Save and reload a room map (relocalization) | `ARSession.getCurrentWorldMap(completionHandler:)`, `ARWorldTrackingConfiguration.initialWorldMap`, `ARWorldMap: NSSecureCoding` | None. `SpatialTrackingSession` (RealityFoundation, iOS 18.0) offers only `.world`, `.plane`, `.image` and `.object` anchor capabilities, and no map persistence |
| Plane classification | `ARPlaneAnchor.classification` (floor, wall, ceiling, table, seat, …) | Plane anchors only |
| LiDAR room mesh | `ARWorldTrackingConfiguration.sceneReconstruction`, `supportsSceneReconstruction(_:)` | Not exposed |
| Session interruptions | `ARSessionObserver.sessionWasInterrupted`, `sessionInterruptionEnded`, `sessionShouldAttemptRelocalization` | Not exposed |

`RealityView` with `RealityViewCamera.spatialTracking` (`_RealityKit_SwiftUI`) can't save or reload a room, and relocalization is required (→ E1.S3.T3). So the app uses **`ARView`** (`RealityKit.swiftmodule`, `open class ARView`, iOS 13+). It isn't deprecated on iOS; only the old `init(frame:)`/`cameraMode` initializer is, in favour of `init(frame:cameraMode:automaticallyConfigureSession:)`. It exposes `public var session: ARKit.ARSession`. SwiftUI hosts it with `UIViewRepresentable`.

## Capabilities and the exact APIs

| Probe | API (declaration) | Availability | Notes |
|---|---|---|---|
| World tracking | `ARWorldTrackingConfiguration.isSupported`, `.planeDetection` (`ARPlaneDetection` horizontal/vertical) | iOS 11+ | `isSupported` is false in the simulator, so the app picks the labelled simulated room |
| Relocalization (T3) | `ARSession.getCurrentWorldMap(completionHandler:)` (`ARSession.h:155`); `ARFrame.worldMappingStatus`, with values `NotAvailable`/`Limited`/`Extending`/`Mapped` (`ARFrame.h:57–69`); `initialWorldMap` (`ARConfiguration.h:296`) | iOS 12+ | Save only when the mapping status is `.extending` or `.mapped`. Restored `ARAnchor`s, matched by name, show that relocalization worked |
| LiDAR mesh (T4) | `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)` (`:398`), `.sceneReconstruction` (`:408`) | iOS 13.4+ | Only on devices with a depth sensor; the app's "camera only" mode follows from `false` |
| Real-geometry collision (T4) | `ARView.Environment.SceneUnderstanding.Options.collision` (`RealityKit…swiftinterface:410`); `CollisionGroup.sceneUnderstanding` (`RealityFoundation…:14408`); `Scene.convexCast(convexShape:fromPosition:fromOrientation:toPosition:toOrientation:query:mask:relativeTo:)` (`:14474`) | iOS 13.4+ | The same contact tolerance as visionOS (`OrientedBox.realWorldContactTest`) is tested on the device |
| Occlusion (T4) | `SceneUnderstanding.Options.occlusion` (`:408`); `ARFrameSemanticPersonSegmentationWithDepth` (`ARConfiguration.h:51`) with `supportsFrameSemantics(_:)` (`:201`); `ARView.RenderOptions.disablePersonOcclusion` (`:619`) | iOS 13+ | The room mesh occludes only on depth-sensor devices; people occlusion needs `supportsFrameSemantics` |
| Lighting (T5) | `PointLightComponent`/`SpotLightComponent`; `SceneUnderstanding.Options.receivesLighting` (`:409`); `ARWorldTrackingConfiguration.environmentTexturing` (`:639`); `ARConfiguration.lightEstimationEnabled` (`:165`), `ARLightEstimate.ambientIntensity`/`ambientColorTemperature` | iOS 13.4+ (`receivesLighting`) | **`PointLightComponent.SurroundingsLight` and `SpotLightComponent.SurroundingsLight` are `@available(iOS, unavailable)`** (`RealityFoundation…:4513–4516`, `:5983–5988`). They are visionOS 27/macOS 27 only. The iOS route to a virtual lamp lighting the real wall is the LiDAR room mesh receiving virtual light (`receivesLighting`), not the camera image. Whether that looks acceptable is the device question for **ID-3** |
| Room photo (T6) | `ARView.snapshot(saveToHDR:completion:)` (`:319`); `PHPhotoLibrary.requestAuthorizationForAccessLevel:handler:` with `PHAccessLevelAddOnly` (`Photos.framework/Headers/PHPhotoLibrary.h:32, :74`) | iOS 13+ / iOS 14+ | The snapshot is the composited camera image plus content. Saving needs `NSPhotoLibraryAddUsageDescription`; add-only access can't read the library |
| Coaching | `ARCoachingOverlayView` (`ARKit/Headers/ARCoachingOverlayView.h`) | iOS 13+ | For I1.S2.T2 |
| Placement raycast | `ARView.raycast(from:allowing:alignment:)` (`:568`) | iOS 13+ | Places probe objects on existing planes |

## Consequences

- **I1 builds on `ARSession` + `ARView`.** `RealityView`/`SpatialTrackingSession` is not used. Revisit only if a later SDK adds map persistence.
- **ID-3 is real.** iOS has no equivalent of visionOS physical-space lighting. The candidate is LiDAR-mesh `receivesLighting`, which isn't available on camera-only devices. The founder decides after the T5 device run.
- **No older-OS branches.** Every API above is older than iOS 27, but the app's minimum is iOS 27.0, so it needs no `#available` checks.
