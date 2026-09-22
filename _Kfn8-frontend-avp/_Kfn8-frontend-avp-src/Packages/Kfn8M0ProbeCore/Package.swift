// swift-tools-version: 6.0
// Kfn8 M0 probe control state. Pure Swift, no RealityKit/ARKit imports, so it is testable on the macOS host
// with the Xcode 27 toolchain and reused unchanged by the nonshipping visionOS 27 probe app.
import PackageDescription

let package = Package(
    name: "Kfn8M0ProbeCore",
    platforms: [.visionOS("27.0"), .macOS("26.0")],
    products: [
        .library(name: "Kfn8M0ProbeCore", targets: ["Kfn8M0ProbeCore"]),
    ],
    targets: [
        .target(
            name: "Kfn8M0ProbeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "Kfn8M0ProbeCoreTests",
            dependencies: ["Kfn8M0ProbeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
