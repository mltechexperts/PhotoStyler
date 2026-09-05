#if targetEnvironment(simulator)
import CoreImage
import Foundation

/// Stands in for the camera on the Simulator, which has no capture hardware.
///
/// Without this the entire styled-camera UI — profile strip, shutter, live
/// grading — is unreachable outside a physical device, which makes it
/// untestable in CI and unverifiable during development. Frames are the same
/// `SampleImage` the shop previews use, slowly panned so the feed reads as live.
nonisolated final class SimulatedCameraFeed: @unchecked Sendable {

    private let queue = DispatchQueue(label: "com.mlcreativestudios.PhotoStyler.simfeed")
    private var timer: DispatchSourceTimer?
    private var phase: CGFloat = 0

    private let onFrame: @Sendable (CIImage) -> Void

    init(onFrame: @escaping @Sendable (CIImage) -> Void) {
        self.onFrame = onFrame
    }

    func start(fps: Int = 15) {
        queue.async { [self] in
            guard timer == nil else { return }
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now(), repeating: .milliseconds(1000 / fps))
            source.setEventHandler { [self] in emitFrame() }
            timer = source
            source.resume()
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
        }
    }

    private func emitFrame() {
        phase += 0.012
        let drift = sin(phase) * 12
        let image = SampleImage.image.transformed(
            by: CGAffineTransform(translationX: drift, y: drift * 0.4)
        )
        onFrame(image.cropped(to: SampleImage.image.extent))
    }
}
#endif
