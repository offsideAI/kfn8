import Foundation

/// Control state for the physical space lighting probe. The device evidence is an on/off comparison of a virtual
/// lamp lighting a real wall or floor. The state records the exact setup so captures are repeatable.
public struct LightingProbeState: Sendable, Equatable {
    public enum LightType: String, Codable, Sendable, CaseIterable { case point, spot }

    public var lightType: LightType = .point
    public var isLightOn = false
    public var surroundingsLightingEnabled = true
    /// RealityKit intensity units. The SDK's own point-light default is 26963.76; the first device run used 2000 and
    /// showed nothing, so the default now matches the SDK and the range allows a much brighter lamp.
    public var intensity: Float = 27000
    public var attenuationRadius: Float = 6
    /// A bone-coloured virtual panel behind the lamp. If the lamp lights this but not the real wall, the light works
    /// and the question is scene understanding; if it lights neither, the light itself is not working.
    public var showVirtualTestPanel = true
    public private(set) var comparisons: [Comparison] = []

    public struct Comparison: Sendable, Equatable, Codable {
        public var lightType: LightType
        public var intensity: Float
        public var surroundingsLightingEnabled: Bool
        public var observedOnWall: String
        public var observedOnFloor: String
        public var frameTimes: FrameTimeStatistics.Summary?
    }

    public init() {}

    public mutating func toggleLight() { isLightOn.toggle() }

    /// A comparison is only meaningful when the light was actually on during the observation.
    public mutating func recordComparison(observedOnWall: String, observedOnFloor: String,
                                          frameTimes: FrameTimeStatistics.Summary?) -> Bool {
        guard isLightOn else { return false }
        comparisons.append(Comparison(lightType: lightType, intensity: intensity,
                                      surroundingsLightingEnabled: surroundingsLightingEnabled,
                                      observedOnWall: observedOnWall, observedOnFloor: observedOnFloor,
                                      frameTimes: frameTimes))
        return true
    }

    public var expectedBehaviour: String {
        surroundingsLightingEnabled
            ? "Virtual \(lightType.rawValue) light visibly brightens the real wall and floor near the lamp; turning it off removes that contribution."
            : "Without SurroundingsLight the real wall and floor do not change when the light toggles."
    }
}
