import Foundation

/// Control state for the Environment Occlusion probe: a virtual object walked behind real furniture.
public struct OcclusionProbeState: Sendable, Equatable {
    public enum BlendingMode: String, Codable, Sendable, CaseIterable {
        case defaultBlending
        case occludedBySurroundings
    }

    public var mode: BlendingMode = .occludedBySurroundings
    public var objectDistanceMetres: Float = 1.5
    public private(set) var observations: [Observation] = []

    public struct Observation: Sendable, Equatable, Codable {
        public var mode: BlendingMode
        public var distanceMetres: Float
        public var edgeQuality: String
        public var artifactsWhileMoving: String
        public var frameTimes: FrameTimeStatistics.Summary?
    }

    public init() {}

    public mutating func toggleMode() {
        mode = mode == .defaultBlending ? .occludedBySurroundings : .defaultBlending
    }

    public mutating func record(edgeQuality: String, artifactsWhileMoving: String, frameTimes: FrameTimeStatistics.Summary?) {
        observations.append(Observation(mode: mode, distanceMetres: objectDistanceMetres, edgeQuality: edgeQuality,
                                        artifactsWhileMoving: artifactsWhileMoving, frameTimes: frameTimes))
    }

    public var expectedBehaviour: String {
        switch mode {
        case .occludedBySurroundings:
            "Real furniture in front of the object hides the overlapping part; edges track while turning and walking."
        case .defaultBlending:
            "Object renders on top of real furniture regardless of depth."
        }
    }
}
