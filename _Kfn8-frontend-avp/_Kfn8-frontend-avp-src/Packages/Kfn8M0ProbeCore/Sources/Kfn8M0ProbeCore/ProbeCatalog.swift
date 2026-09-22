import Foundation

/// The M0 probes, in roadmap order. Blocking probes gate M1; nonblocking ones only inform scope decisions.
public enum ProbeKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case lighting
    case occlusion
    case manipulation
    case export
    case splat

    public var id: String { rawValue }

    public var isBlocking: Bool {
        switch self {
        case .lighting, .occlusion, .manipulation: true
        case .export, .splat: false
        }
    }

    public var title: String {
        switch self {
        case .lighting: "Physical space lighting"
        case .occlusion: "Environment occlusion"
        case .manipulation: "ManipulationComponent"
        case .export: "Passthrough still export"
        case .splat: "Gaussian splat (one attempt)"
        }
    }

    /// Exact public symbols read from the installed visionOS 27.0 SDK swiftinterface files on 2026-09-22.
    /// These are citations, not assumptions; the app target compiles against them.
    public var sdkSymbols: [String] {
        switch self {
        case .lighting:
            ["RealityKit.PointLightComponent.SurroundingsLight (visionOS 27.0)",
             "RealityKit.SpotLightComponent.SurroundingsLight (visionOS 27.0)",
             "RealityKit.SpotLightComponent.Shadow.quality / lightSize (visionOS 27.0)"]
        case .occlusion:
            ["RealityKit.EnvironmentBlendingComponent(preferredBlendingMode: .occluded(by: .surroundings)) (visionOS 26.0)"]
        case .manipulation:
            ["RealityKit.ManipulationComponent (visionOS 26.0): dynamics, releaseBehavior (.reset/.stay)",
             "RealityKit.ManipulationComponent.configureEntity(_:hoverEffect:allowedInputTypes:collisionShapes:)",
             "RealityKit.ManipulationEvents.WillBegin/DidUpdateTransform/WillRelease(wasCancelled)/WillEnd/DidHandOff",
             "RealityKit.ManipulationComponent.InputDevice.Kind: indirectPinch, directPinch, pointer"]
        case .export:
            ["ScreenCaptureKit.SCStream / SCContentFilter / SCStreamOutput (visionOS 27.0)",
             "ScreenCaptureKit.SCContentSharingPicker (visionOS 27.0)",
             "ScreenCaptureKit.SCScreenshotManager: API_UNAVAILABLE(visionos)",
             "ARKit.CameraFrameProvider requires ARKitSession.AuthorizationType.cameraAccess (enterprise entitlement)"]
        case .splat:
            ["RealityKit.GaussianSplatResource(BufferResource) (visionOS 27.0): buffer initialiser only; no file loader in swiftinterface",
             "RealityKit.GaussianSplatComponent, GaussianSplatEvents.RenderingChanged (visionOS 27.0)"]
        }
    }
}

/// Outcome vocabulary shared by every probe. `notRun` is the truthful default until device evidence exists.
public enum ProbeOutcome: String, Codable, Sendable {
    case notRun
    case passed
    case failed
    case unavailable
    case inconclusive
}
