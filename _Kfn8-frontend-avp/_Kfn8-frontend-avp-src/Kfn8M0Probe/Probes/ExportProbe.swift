import CoreImage
import CoreMedia
import Foundation
import Kfn8M0ProbeCore
import os

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit

/// Nonblocking still-export probe using the only third-party capture route the visionOS 27 SDK exposes:
/// ScreenCaptureKit's user-driven content sharing picker plus an SCStream. Whether the delivered frame contains real
/// passthrough pixels is the device question this probe answers; the founder opens the written file to check.
/// `SCScreenshotManager` is unavailable on visionOS and ARKit main-camera access needs an enterprise entitlement.
@MainActor
final class ExportProbeCoordinator: NSObject {
    weak var session: ProbeSession?
    private var stream: SCStream?
    private let output = FirstFrameOutput()

    var isAvailable: Bool { SCContentSharingPicker.shared.isAvailable }

    func begin() {
        guard let session else { return }
        guard session.export.beginCapture() else {
            session.lastError = "Export attempted without consent; refused."
            return
        }
        guard isAvailable else {
            session.export.markUnavailable("SCContentSharingPicker.isAvailable == false on this device/simulator")
            session.record(.export, expected: "Picker available", observed: "SCContentSharingPicker unavailable", outcome: .unavailable, includeFrameTimes: false)
            return
        }
        output.onFrameWritten = { [weak self] result in
            Task { @MainActor in self?.handle(result) }
        }
        let picker = SCContentSharingPicker.shared
        picker.isActive = true
        picker.add(self)
        picker.present()
    }

    private func handle(_ result: Result<(URL, Int), any Error>) {
        defer { stopStream() }
        guard let session else { return }
        switch result {
        case .success(let (url, bytes)):
            session.export.finishCapture(fileURL: url, byteCount: bytes)
            session.record(.export, expected: "PNG of passthrough room plus placements",
                           observed: "Wrote \(bytes) bytes to \(url.lastPathComponent); founder must open it and confirm real room pixels",
                           outcome: .inconclusive, includeFrameTimes: false)
        case .failure(let error):
            session.export.fail(error.localizedDescription)
            session.record(.export, expected: "PNG written", observed: "Capture failed: \(error.localizedDescription)", outcome: .failed, includeFrameTimes: false)
        }
    }

    private func startStream(with filter: SCContentFilter) {
        let configuration = SCStreamConfiguration()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        do {
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue(label: "kfn8.m0.export"))
        } catch {
            handle(.failure(error))
            return
        }
        self.stream = stream
        stream.startCapture { [weak self] error in
            if let error {
                Task { @MainActor in self?.handle(.failure(error)) }
            }
        }
    }

    private func stopStream() {
        SCContentSharingPicker.shared.remove(self)
        SCContentSharingPicker.shared.isActive = false
        stream?.stopCapture { _ in }
        stream = nil
    }
}

extension ExportProbeCoordinator: SCContentSharingPickerObserver {
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            self.session?.export.fail("Picker cancelled")
            self.session?.record(.export, expected: "Picker selection", observed: "User cancelled picker", outcome: .inconclusive, includeFrameTimes: false)
            self.stopStream()
        }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        // SCContentFilter is an ObjC object the SDK does not mark Sendable; it is created by the system for us and
        // handed over here, so transferring it to the main actor is the intended ownership.
        nonisolated(unsafe) let transferred = filter
        Task { @MainActor in self.startStream(with: transferred) }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in self.handle(.failure(error)) }
    }
}

/// Writes the first delivered screen frame as PNG into Documents, then ignores the rest. Runs on the sample queue.
private final class FirstFrameOutput: NSObject, SCStreamOutput, Sendable {
    private let state = OSAllocatedUnfairLock<Bool>(initialState: false)
    nonisolated(unsafe) var onFrameWritten: (@Sendable (Result<(URL, Int), any Error>) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let firstFrame = state.withLock { taken -> Bool in
            if taken { return false }
            taken = true
            return true
        }
        guard firstFrame else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        do {
            guard let data = context.pngRepresentation(of: image, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else {
                throw ExportError.encodingFailed
            }
            let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let url = directory.appendingPathComponent("M0-export-probe.png")
            try data.write(to: url, options: .atomic)
            onFrameWritten?(.success((url, data.count)))
        } catch {
            onFrameWritten?(.failure(error))
        }
    }
}

enum ExportError: LocalizedError {
    case encodingFailed
    var errorDescription: String? { "PNG encoding failed" }
}

#else
/// The visionOS 27.0 simulator SDK does not ship ScreenCaptureKit (verified 2026-09-22: no framework under
/// XRSimulator.sdk). The probe reports that honestly instead of pretending a capture happened.
@MainActor
final class ExportProbeCoordinator: NSObject {
    weak var session: ProbeSession?
    var isAvailable: Bool { false }

    func begin() {
        guard let session else { return }
        guard session.export.beginCapture() else {
            session.lastError = "Export attempted without consent; refused."
            return
        }
        session.export.markUnavailable("ScreenCaptureKit is absent from the visionOS simulator SDK; device run required")
        session.record(.export, expected: "ScreenCaptureKit stream frame", observed: "Simulator SDK has no ScreenCaptureKit",
                       outcome: .unavailable, includeFrameTimes: false)
    }
}
#endif
