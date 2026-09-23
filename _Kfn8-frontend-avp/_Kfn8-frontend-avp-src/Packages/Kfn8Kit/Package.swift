// swift-tools-version: 6.0
// Kfn8 client core: pure domain rules and local persistence. No RealityKit/ARKit, so every target is tested on the
// macOS host with the Xcode 27 toolchain and reused unchanged by the visionOS app.
import PackageDescription

let strict: [SwiftSetting] = [.swiftLanguageMode(.v6), .enableUpcomingFeature("ExistentialAny")]

let package = Package(
    name: "Kfn8Kit",
    platforms: [.visionOS("27.0"), .macOS("26.0")],
    products: [
        .library(name: "Kfn8Domain", targets: ["Kfn8Domain"]),
        .library(name: "Kfn8Persistence", targets: ["Kfn8Persistence"]),
        .library(name: "Kfn8Catalogue", targets: ["Kfn8Catalogue"]),
    ],
    targets: [
        .target(name: "Kfn8Domain", swiftSettings: strict),
        .target(name: "Kfn8Persistence", dependencies: ["Kfn8Domain"], swiftSettings: strict),
        .target(name: "Kfn8Catalogue", dependencies: ["Kfn8Domain"], swiftSettings: strict),
        .testTarget(name: "Kfn8CatalogueTests", dependencies: ["Kfn8Catalogue"], resources: [.copy("Fixtures")], swiftSettings: strict),
        .testTarget(name: "Kfn8DomainTests", dependencies: ["Kfn8Domain"], swiftSettings: strict),
        .testTarget(name: "Kfn8PersistenceTests", dependencies: ["Kfn8Persistence"], swiftSettings: strict),
    ]
)
