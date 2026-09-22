# M0 SDK API evidence (E0.S2.T1)

Date: 2026-09-22. Source: the installed Xcode 27.0 (27A266a) visionOS 27.0 SDK swiftinterface and header files, read directly. No marketing names were accepted; every symbol below exists in the SDK the probe compiles against.

Paths inspected:

- `…/XROS.sdk/System/Library/Frameworks/RealityFoundation.framework/Modules/RealityFoundation.swiftmodule/arm64e-apple-xros.swiftinterface`
- `…/XROS.sdk/System/Library/Frameworks/RealityKit.framework/Modules/RealityKit.swiftmodule/arm64e-apple-xros.swiftinterface`
- `…/XROS.sdk/usr/lib/swift/ARKit.swiftmodule/arm64e-apple-xros.swiftinterface`
- `…/XROS.sdk/System/Library/Frameworks/ScreenCaptureKit.framework/Headers/*.h`
- `…/XROS.sdk/System/Library/Frameworks/ReplayKit.framework/Headers/RPScreenRecorder.h`

## Blocking probe 1: physical space lighting

| Symbol | Availability | Notes |
|---|---|---|
| `PointLightComponent.SurroundingsLight` | visionOS 27.0, macOS 27.0; iOS/tvOS/Catalyst unavailable | Empty marker component set on the same entity as `PointLightComponent`. This is the API that lets a virtual light illuminate real surroundings. |
| `SpotLightComponent.SurroundingsLight` | visionOS 27.0, macOS 27.0 | Same pattern for spot lights. |
| `SpotLightComponent.Shadow.quality` (`.low/.medium/.high`), `.lightSize` | visionOS 27.0 | Shadow is a separate component set on the light entity. |
| `PointLightComponent(color:intensity:attenuationRadius:)` | visionOS 2.0+ | `attenuationFalloffExponent` also available. |
| `PortalComponent.lightingBlendDistance` | visionOS 27.0 | Not used by MVP1 (no portals). |

Permissions: none. Lighting is a rendering feature, not an ARKit data provider.

## Blocking probe 2: Environment Occlusion

| Symbol | Availability | Notes |
|---|---|---|
| `EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings))` | visionOS 26.0 | `EnvironmentType` has a single case `surroundings`; `BlendingMode` has `.default` and `.occluded(by:)`. |

Permissions: none for the component itself. The probe's collision-only mesh entities (for placement validation) additionally use ARKit `SceneReconstructionProvider`, which requires `worldSensing` authorization and `NSWorldSensingUsageDescription`. Those mesh entities carry no model or `OcclusionMaterial`, so they cannot confound the occlusion measurement.

## Blocking probe 3: ManipulationComponent

| Symbol | Availability | Notes |
|---|---|---|
| `ManipulationComponent` | visionOS 26.0 | `dynamics` (translation/rotation/scaling behaviours, inertia), `releaseBehavior` (`.reset`, `.stay`), `audioConfiguration`. |
| `ManipulationComponent.configureEntity(_:hoverEffect:allowedInputTypes:collisionShapes:)` | visionOS 26.0 | Adds input target, collision and hover effect. |
| `ManipulationComponent.InputDevice.Kind` | visionOS 26.0 | `indirectPinch`, `directPinch`, `pointer`; `chirality` and `pose` per device. |
| `ManipulationEvents.WillBegin / DidUpdateTransform / WillRelease(wasCancelled) / WillEnd / DidHandOff` | visionOS 26.0 | Subscribed via `RealityViewContent.subscribe(to:)`. |
| `Scene.convexCast(convexShape:fromPosition:fromOrientation:toPosition:toOrientation:query:mask:)` | available | Used to validate a released pose against real-world mesh collision. |
| `ShapeResource.generateStaticMesh(from: MeshAnchor)` | RealityKit on visionOS | Converts ARKit mesh anchors into collision shapes. |

**Finding for the invalid-release requirement:** the SDK exposes no API to keep a manipulation alive after the system reports `WillRelease`, and no API to begin a manipulation programmatically. `releaseBehavior = .stay` keeps the entity where it was released; the app can hold an unsaved preview state, but any further movement requires the user to pinch again. The probe counts `DidUpdateTransform` events that arrive after a release without a new `WillBegin` to measure whether the platform behaves differently on device. If the count stays zero on the M2, "continue without re-grab" is not supported by the platform and the founder must choose between (a) held unsaved preview plus re-grab, or (b) another interaction. That is a product decision, not a workaround to be made silently.

ARKit for attachment surfaces: `PlaneDetectionProvider(alignments: [.horizontal, .vertical])`, `PlaneAnchor.surfaceClassification` (`classification` is deprecated since visionOS 26.0) with cases including `wall`, `floor`, `ceiling`, `table`, `seat`, `window`, `door`, `stairs`, `bed`, `cabinet`, `homeAppliance`, `tv`, `plant`; `PlaneAnchor.geometry.extent` (`width`, `height`, `anchorFromExtentTransform`). Authorization: `ARKitSession.requestAuthorization(for: [.worldSensing])`.

## Nonblocking probe 4: passthrough still export

| Route | Availability | Verdict from SDK |
|---|---|---|
| `SCScreenshotManager` (ScreenCaptureKit) | `API_UNAVAILABLE(visionos)` | Not usable. |
| `SCStream` + `SCContentFilter` + `SCStreamOutput` + `SCContentSharingPicker` | visionOS 27.0 | Usable; user-driven picker. `SCStreamConfiguration.width/height/pixelFormat/minimumFrameInterval` are unavailable on visionOS, so defaults apply. `SCContentSharingPicker.isAvailable` (visionOS 27.0) reports device support. **Whether the delivered frame contains passthrough pixels is unknown until run on device.** |
| `SCRecordingOutput` | visionOS 27.0 | Video alternative; not used by the probe. |
| `RPScreenRecorder` (ReplayKit) | present, deprecated in favour of ScreenCaptureKit in the 27 headers | Not used. |
| ARKit `CameraFrameProvider` | visionOS 2.0+, requires `ARKitSession.AuthorizationType.cameraAccess` | Main-camera access is an enterprise entitlement, not consumer-distributable. Not an MVP1 route. |
| `ARView.snapshot` | ARView is not the visionOS immersive rendering path | Not applicable. |

The simulator SDK (`XRSimulator.sdk`) ships no `ScreenCaptureKit.framework` at all, so the probe compiles the export coordinator only under `#if canImport(ScreenCaptureKit)` and reports "unavailable" on the simulator. This is an SDK gap, not an older-OS shim.

## Nonblocking probe 5: Gaussian splats

| Symbol | Availability | Notes |
|---|---|---|
| `GaussianSplatResource` | visionOS 27.0 | Only initialiser: `init(_ bufferResource: BufferResource)`. `BufferResource(count:position:scale:rotation:opacity:sphericalHarmonics:)` takes `LowLevelBuffer` descriptors. No `load(contentsOf:)`, no PLY/SPZ reader in the public interface. |
| `GaussianSplatComponent(_:)` | visionOS 27.0 | Attach the resource to an entity. |
| `GaussianSplatEvents.RenderingChanged` | visionOS 27.0 | `renderingStatus` (`normal/medium/low`), `isRenderingLimited`. |

Approved sample (https://note.com/steam_studio/n/ne9736d94f162): CC0, Box folder link only (browser interaction required, no direct URL), formats are uncompressed PLY (~719k splats, 159 MB) and SuperSplat-compressed PLY plus RealityCapture meshes. **Result: no readily available splat asset in a RealityKit-ingestable form.** A PLY parser writing `GaussianSplatResource.BufferResource` would be needed; that is the v1.1 conversion dependency. One fetch was spent; no further research, per the budget.
