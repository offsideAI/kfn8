// swift-tools-version: 6.0
// Pure state for the nonshipping iPhone/iPad feasibility probe (I0.S2): evidence records, observation chips, the
// bounded relocalization timer and the consent-gated photo flow. No ARKit/RealityKit, so it is tested on the macOS host.
import PackageDescription

let strict: [SwiftSetting] = [.swiftLanguageMode(.v6), .enableUpcomingFeature("ExistentialAny")]

let package = Package(
    name: "Kfn8iOSProbeCore",
    platforms: [.iOS("27.0"), .macOS("26.0")],
    products: [.library(name: "Kfn8iOSProbeCore", targets: ["Kfn8iOSProbeCore"])],
    targets: [
        .target(name: "Kfn8iOSProbeCore", swiftSettings: strict),
        .testTarget(name: "Kfn8iOSProbeCoreTests", dependencies: ["Kfn8iOSProbeCore"], swiftSettings: strict),
    ]
)
