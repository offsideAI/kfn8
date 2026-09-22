import Kfn8M0ProbeCore
import RealityKit
import SwiftUI

/// Mixed Immersive Space hosting all fixtures. Subscribes to the platform's manipulation lifecycle and forwards it to
/// the session so expected-versus-observed behaviour is recorded from real events, not assumptions.
struct ProbeImmersiveView: View {
    @Environment(ProbeSession.self) private var session

    var body: some View {
        RealityView { content in
            session.scene.build()
            content.add(session.scene.root)
            content.add(session.surfaces.realWorldRoot)
            session.scene.applyLighting(session.lighting)
            session.scene.applyOcclusion(session.occlusion)
            subscribe(content)
            FrameTimeSink.shared.isRecording = true
        }
        .task {
            await session.surfaces.start()
        }
        .onDisappear {
            FrameTimeSink.shared.isRecording = false
            session.surfaces.stop()
        }
    }

    private func subscribe(_ content: RealityViewContent) {
        session.subscriptions.removeAll()
        session.subscriptions.append(content.subscribe(to: ManipulationEvents.WillBegin.self) { event in
            guard let affinity = affinity(of: event.entity) else { return }
            let kinds = Set(event.inputDeviceSet.map { inputKind($0.kind) })
            session.manipulationWillBegin(affinity: affinity, inputKinds: kinds)
        })
        session.subscriptions.append(content.subscribe(to: ManipulationEvents.DidUpdateTransform.self) { event in
            guard let affinity = affinity(of: event.entity) else { return }
            session.manipulationDidUpdate(affinity: affinity, position: event.entity.position(relativeTo: nil))
        })
        session.subscriptions.append(content.subscribe(to: ManipulationEvents.DidHandOff.self) { event in
            guard let affinity = affinity(of: event.entity) else { return }
            session.manipulationDidHandOff(affinity: affinity)
        })
        session.subscriptions.append(content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
            guard let affinity = affinity(of: event.entity) else { return }
            session.manipulationWillRelease(affinity: affinity, wasCancelled: event.wasCancelled,
                                            releasedPosition: event.entity.position(relativeTo: nil),
                                            releasedYaw: session.scene.yaw(of: affinity))
        })
        session.subscriptions.append(content.subscribe(to: ManipulationEvents.WillEnd.self) { event in
            guard let affinity = affinity(of: event.entity) else { return }
            session.manipulationWillEnd(affinity: affinity)
        })
    }

    private func affinity(of entity: Entity) -> AttachmentAffinity? {
        entity.components[FixtureComponent.self]?.affinity
    }

    private func inputKind(_ kind: ManipulationComponent.InputDevice.Kind) -> ManipulationProbeState.InputKind {
        switch kind {
        case .indirectPinch: .indirectPinch
        case .directPinch: .directPinch
        case .pointer: .pointer
        @unknown default: .unknown
        }
    }
}
