import AVFoundation
import Observation
import OSLog
import SwiftUI

/// UI-facing camera state.
///
/// `@Observable` replaces the previous `ObservableObject`/`@Published` pair,
/// which is also what removes the explicit `import Combine` the build needed:
/// this target enables `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, so
/// `@Published` was no longer visible through `import SwiftUI`.
@MainActor
@Observable
final class CameraModel {

    private static let logger = Logger(
        subsystem: "com.mlcreativestudios.PhotoStyler", category: "camera-model"
    )

    enum Phase: Equatable {
        case idle
        case preparing
        case running
        /// Permission was refused. Distinct from `failed` because the user can
        /// fix it in Settings, so the UI offers a different action.
        case denied
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var isCapturing = false
    private(set) var recentImage: UIImage?
    private(set) var isFlashSupported = false
    private(set) var isFrontCamera = false
    private(set) var focusIndicator: CGPoint?

    var isFlashOn = false
    var zoom: CGFloat = 1 { didSet { Task { await controller.setZoom(zoom) } } }

    /// Surfaced as a transient banner; capture failures should not tear down the
    /// viewfinder.
    private(set) var transientError: String?

    let controller = CameraController()
    private var eventTask: Task<Void, Never>?

    var session: AVCaptureSession { controller.session }

    // MARK: - Lifecycle

    func onAppear() async {
        guard phase != .running else { return }
        phase = .preparing

        #if DEBUG
        // System permission alerts cannot be driven reliably from UI tests or
        // screenshot automation, so the unhappy paths are reachable directly.
        if let forced = Self.forcedPhaseFromLaunchArguments {
            phase = forced
            return
        }
        #endif

        switch CameraController.authorizationStatus {
        case .authorized:
            break
        case .notDetermined:
            guard await CameraController.requestAccess() else {
                phase = .denied
                return
            }
        default:
            phase = .denied
            return
        }

        observeCameraEvents()

        do {
            try await controller.configure()
            await controller.start()
            isFlashSupported = controller.supportedFlashModes.contains(.on)
            isFrontCamera = controller.position == .front
            phase = .running
        } catch {
            Self.logger.error("Camera setup failed: \(error.localizedDescription, privacy: .public)")
            phase = .failed(error.localizedDescription)
        }
    }

    func onDisappear() async {
        eventTask?.cancel()
        eventTask = nil
        await controller.stop()
        phase = .idle
    }

    private func observeCameraEvents() {
        guard eventTask == nil else { return }
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.controller.events {
                switch event {
                case .interrupted(let reason):
                    self.transientError = reason
                case .interruptionEnded:
                    self.transientError = nil
                    await self.controller.resumeAfterInterruption()
                case .runtimeError(let message):
                    self.phase = .failed(message)
                }
            }
        }
    }

    // MARK: - Actions

    func capture() async {
        guard phase == .running, !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let mode: AVCaptureDevice.FlashMode = (isFlashOn && isFlashSupported) ? .on : .off
            let data = try await controller.capturePhoto(flashMode: mode)
            recentImage = UIImage(data: data)
            try await PhotoLibrarySaver.save(data)
        } catch {
            transientError = error.localizedDescription
            Self.logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func flipCamera() async {
        do {
            try await controller.flipCamera()
            isFrontCamera = controller.position == .front
            isFlashSupported = controller.supportedFlashModes.contains(.on)
            // The front camera has no flash; leaving the toggle lit would lie.
            if !isFlashSupported { isFlashOn = false }
            zoom = 1
        } catch {
            transientError = error.localizedDescription
        }
    }

    func focus(at devicePoint: CGPoint, layerPoint: CGPoint) async {
        focusIndicator = layerPoint
        await controller.focus(at: devicePoint)
        try? await Task.sleep(for: .seconds(1))
        if focusIndicator == layerPoint { focusIndicator = nil }
    }

    func dismissError() { transientError = nil }

    #if DEBUG
    private static var forcedPhaseFromLaunchArguments: Phase? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-forceCameraDenied") { return .denied }
        if arguments.contains("-forceCameraFailed") {
            return .failed("The camera is in use by another app.")
        }
        return nil
    }
    #endif

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
