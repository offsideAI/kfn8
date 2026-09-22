import RealityKit
import SwiftUI

/// Nonshipping M0 probe. visionOS 27 only, Mixed Immersive Space only, no accounts, no analytics, no upload.
@main
struct Kfn8M0ProbeApp: App {
    @State private var session = ProbeSession()
    @State private var immersionStyle: any ImmersionStyle = .mixed

    init() {
        // RealityKit only picks up custom systems/components registered before any scene is created.
        FixtureComponent.registerComponent()
        FrameTimeSystem.registerSystem()
    }

    var body: some SwiftUI.Scene {
        WindowGroup(id: ProbeSession.controlWindowID) {
            ProbeControlView()
                .environment(session)
        }
        .defaultSize(width: 720, height: 900)

        ImmersiveSpace(id: ProbeSession.immersiveSpaceID) {
            ProbeImmersiveView()
                .environment(session)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}
