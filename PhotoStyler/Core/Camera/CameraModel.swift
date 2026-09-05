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

    /// Profiles offered in the strip over the viewfinder.
    private(set) var profiles: [StyleProfile] = [.original]
    private(set) var selectedProfile: StyleProfile = .original
    var intensity: Float = 1 { didSet { pushStyle() } }

    private let catalogRepository: any ProfileRepository

    #if targetEnvironment(simulator)
    private var simulatedFeed: SimulatedCameraFeed?
    #endif

    init(repository: any ProfileRepository = BundledProfileRepository()) {
        self.catalogRepository = repository
    }

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

        await loadProfiles()

        do {
            try await controller.configure()
            await controller.start()
            isFlashSupported = controller.supportedFlashModes.contains(.on)
            isFrontCamera = controller.position == .front
            pushStyle()
            phase = .running
        } catch {
            handleCameraUnavailable(error.localizedDescription)
        }
    }

    func onDisappear() async {
        eventTask?.cancel()
        eventTask = nil
        #if targetEnvironment(simulator)
        simulatedFeed?.stop()
        simulatedFeed = nil
        #endif
        await controller.stop()
        phase = .idle
    }

    /// Single place that decides what an unusable camera means.
    ///
    /// On device it is a real failure the user must see. On the Simulator it is
    /// expected, and the synthetic feed keeps the styled UI reachable so the
    /// camera screen stays testable without hardware.
    private func handleCameraUnavailable(_ message: String) {
        #if targetEnvironment(simulator)
        guard simulatedFeed == nil else { return }
        Self.logger.info("Simulator: synthetic feed (\(message, privacy: .public))")
        startSimulatedFeed()
        pushStyle()
        phase = .running
        #else
        Self.logger.error("Camera unavailable: \(message, privacy: .public)")
        phase = .failed(message)
        #endif
    }

    #if targetEnvironment(simulator)
    private func startSimulatedFeed() {
        let controller = controller
        let feed = SimulatedCameraFeed { image in
            controller.renderPreviewFrame(image)
        }
        simulatedFeed = feed
        feed.start()
        isFlashSupported = true
    }
    #endif

    // MARK: - Profiles

    private func loadProfiles() async {
        guard profiles.count <= 1 else { return }
        do {
            profiles = try await catalogRepository.loadProfiles()
        } catch {
            Self.logger.error("Profile load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func select(_ profile: StyleProfile) {
        selectedProfile = profile
        pushStyle()
    }

    private func pushStyle() {
        controller.setStyle(profile: selectedProfile, intensity: intensity)
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
                    // On the Simulator the session configures and starts
                    // cleanly, then fails at first frame because nothing is
                    // behind it — so the runtime error, not configure(), is
                    // where the fallback has to happen.
                    self.handleCameraUnavailable(message)
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
            let raw = try await captureData(flashMode: mode)
            // The same profile the viewfinder showed, applied at full
            // resolution — the preview is downscaled, the saved file is not.
            let styled = try await style(raw)
            recentImage = UIImage(data: styled)
            try await PhotoLibrarySaver.save(styled)
            lastCaptureProfileID = selectedProfile.id
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

    /// `point` is normalised to the preview view (0...1 in each axis).
    func focus(atNormalisedPoint point: CGPoint) async {
        focusIndicator = point
        // AVFoundation's point of interest is expressed in the sensor's
        // landscape space, so x and y swap for a portrait preview.
        await controller.focus(at: CGPoint(x: point.y, y: 1 - point.x))
        try? await Task.sleep(for: .seconds(1))
        if focusIndicator == point { focusIndicator = nil }
    }

    /// Set after a successful capture so the gallery can record which profile
    /// produced the file.
    private(set) var lastCaptureProfileID: String?

    private func captureData(flashMode: AVCaptureDevice.FlashMode) async throws -> Data {
        #if targetEnvironment(simulator)
        if simulatedFeed != nil {
            let processor = ImageProcessor.shared
            let encoded = await Task.detached(priority: .userInitiated) {
                processor.jpegData(SampleImage.image)
            }.value
            guard let encoded else {
                throw CameraError.captureFailed("Could not encode the simulated frame.")
            }
            return encoded
        }
        #endif
        return try await controller.capturePhoto(flashMode: flashMode)
    }

    private func style(_ data: Data) async throws -> Data {
        let profile = selectedProfile
        let value = intensity
        // Nothing to apply for the pass-through profile or at zero intensity;
        // returning the original bytes also preserves the untouched EXIF.
        guard !profile.isOriginal, value > 0 else { return data }
        return try await renderStyled(data, profile: profile, intensity: value)
    }

    private func renderStyled(
        _ data: Data, profile: StyleProfile, intensity: Float
    ) async throws -> Data {
        let processor = ImageProcessor.shared
        let result = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let source = CIImage(data: data) else { return nil }
            let styled = processor.apply(profile: profile, to: source, intensity: intensity)
            // Carry the original EXIF through so date, lens and exposure survive.
            return processor.jpegData(styled, properties: source.properties)
        }.value
        guard let result else {
            throw CameraError.captureFailed("Could not apply the style to the photo.")
        }
        return result
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
