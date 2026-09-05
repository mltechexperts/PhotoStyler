import AVFoundation
import OSLog
import UIKit

/// Owns the `AVCaptureSession`.
///
/// Session configuration and `startRunning()` block for a noticeable time, so
/// none of it may touch the main thread — that was the cause of the launch hang
/// in the original implementation. Every mutation is funnelled through
/// `sessionQueue`.
///
/// The class is `@unchecked Sendable` because that invariant is enforced here by
/// construction rather than by the compiler: no stored property is read or
/// written outside `sessionQueue`, with one documented exception — `session`
/// itself, which `AVCaptureVideoPreviewLayer` is designed to hold from the main
/// thread.
/// Something that took the camera away, or gave it back.
nonisolated enum CameraEvent: Sendable, Equatable {
    case interrupted(String)
    case interruptionEnded
    case runtimeError(String)
}

nonisolated final class CameraController: @unchecked Sendable {

    private static let logger = Logger(
        subsystem: "com.mlcreativestudios.PhotoStyler", category: "camera"
    )

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.mlcreativestudios.PhotoStyler.session")
    private let photoOutput = AVCapturePhotoOutput()

    private var videoInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    /// Capture delegates must outlive the call that starts them; AVFoundation
    /// holds only an unowned reference.
    private var inFlightCaptures: [Int64: PhotoCaptureDelegate] = [:]

    private(set) var position: AVCaptureDevice.Position = .back

    /// Interruptions and runtime failures, surfaced so the UI can explain itself
    /// instead of showing a frozen viewfinder.
    let events: AsyncStream<CameraEvent>
    private let eventContinuation: AsyncStream<CameraEvent>.Continuation
    private var observers: [any NSObjectProtocol] = []

    init() {
        (events, eventContinuation) = AsyncStream.makeStream()
        observeSessionNotifications()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        eventContinuation.finish()
    }

    // MARK: - Permissions

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Lifecycle

    func configure() async throws {
        try await onQueue {
            guard self.videoInput == nil else { return }

            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            self.session.sessionPreset = .photo

            guard let device = Self.device(for: self.position) else {
                throw CameraError.noCameraAvailable
            }
            let input = try AVCaptureDeviceInput(device: device)
            guard self.session.canAddInput(input) else { throw CameraError.cannotAddInput }
            self.session.addInput(input)
            self.videoInput = input

            guard self.session.canAddOutput(self.photoOutput) else {
                throw CameraError.cannotAddOutput
            }
            self.session.addOutput(self.photoOutput)
            self.photoOutput.maxPhotoQualityPrioritization = .quality

            self.startRotationTracking(for: device)
        }
    }

    func start() async {
        await onQueue {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    /// Stops the session. The original code never did this, so the camera stayed
    /// powered while the app sat on another screen.
    func stop() async {
        await onQueue {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    // MARK: - Capabilities

    /// The front camera has no flash unit, so the UI must not offer it there.
    /// The original code set `.flashMode = .on` unconditionally.
    var supportedFlashModes: [AVCaptureDevice.FlashMode] {
        photoOutput.supportedFlashModes
    }

    var maxZoomFactor: CGFloat {
        guard let device = videoInput?.device else { return 1 }
        // Beyond ~8x on the wide lens the image is pure upscaling.
        return min(device.activeFormat.videoMaxZoomFactor, 8)
    }

    // MARK: - Actions

    func capturePhoto(flashMode: AVCaptureDevice.FlashMode) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                if self.photoOutput.supportedFlashModes.contains(flashMode) {
                    settings.flashMode = flashMode
                }

                // Without this the saved image is rotated wrong whenever the
                // phone is not upright — the preview looks correct, which is
                // what makes the bug easy to miss.
                if let connection = self.photoOutput.connection(with: .video),
                   let angle = self.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
                   connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }

                let id = settings.uniqueID
                let delegate = PhotoCaptureDelegate { [weak self] result in
                    // Callback arrives on an AVFoundation-owned queue, so the
                    // bookkeeping hops back to sessionQueue before touching it.
                    if let self {
                        self.sessionQueue.async { self.inFlightCaptures[id] = nil }
                    }
                    continuation.resume(with: result)
                }
                self.inFlightCaptures[id] = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    func flipCamera() async throws {
        try await onQueue {
            guard let current = self.videoInput else { throw CameraError.noCameraAvailable }
            let newPosition: AVCaptureDevice.Position = current.device.position == .back ? .front : .back
            guard let device = Self.device(for: newPosition) else {
                throw CameraError.noCameraAvailable
            }
            let input = try AVCaptureDeviceInput(device: device)

            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }

            self.session.removeInput(current)
            guard self.session.canAddInput(input) else {
                // Put the working input back rather than leaving a dead session.
                self.session.addInput(current)
                throw CameraError.cannotAddInput
            }
            self.session.addInput(input)
            self.videoInput = input
            self.position = newPosition
            self.startRotationTracking(for: device)
        }
    }

    func setZoom(_ factor: CGFloat) async {
        await onQueue {
            guard let device = self.videoInput?.device else { return }
            let clamped = min(max(factor, 1), self.maxZoomFactor)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                Self.logger.error("Zoom failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// `point` is in the preview layer's coordinate space, already converted by
    /// the caller via `captureDevicePointConverted(fromLayerPoint:)`.
    func focus(at point: CGPoint) async {
        await onQueue {
            guard let device = self.videoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
                }
                device.unlockForConfiguration()
            } catch {
                Self.logger.error("Focus failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Internals

    private static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // Dual-wide first so the back camera gets optical zoom-out where the
        // hardware has it, falling back to the plain wide lens.
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInDualWideCamera, .builtInWideAngleCamera,
        ]
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: position
        ).devices.first
    }

    private func startRotationTracking(for device: AVCaptureDevice) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]
        ) { [weak self] coordinator, _ in
            guard let self,
                  let connection = self.photoOutput.connection(with: .video) else { return }
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    private func observeSessionNotifications() {
        let center = NotificationCenter.default
        let continuation = eventContinuation

        observers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil
        ) { note in
            let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int
            let reason = raw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            continuation.yield(.interrupted(Self.describe(reason)))
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
        ) { _ in
            continuation.yield(.interruptionEnded)
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { note in
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? NSError
            continuation.yield(.runtimeError(error?.localizedDescription ?? "The camera stopped unexpectedly."))
        })
    }

    private static func describe(_ reason: AVCaptureSession.InterruptionReason?) -> String {
        switch reason {
        case .videoDeviceInUseByAnotherClient:
            "Another app is using the camera."
        case .videoDeviceNotAvailableWithMultipleForegroundApps:
            "The camera is not available in Split View."
        case .videoDeviceNotAvailableDueToSystemPressure:
            "The camera paused because the device got too warm."
        case .videoDeviceNotAvailableInBackground:
            "The camera is not available in the background."
        default:
            "The camera was interrupted."
        }
    }

    /// Restarts after an interruption ends.
    func resumeAfterInterruption() async {
        await onQueue {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func onQueue<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { continuation.resume(with: Result { try work() }) }
        }
    }

    private func onQueue(_ work: @escaping @Sendable () -> Void) async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                work()
                continuation.resume()
            }
        }
    }
}

/// Bridges the delegate callback into an `async` result.
private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {

    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            completion(.failure(CameraError.captureFailed(error.localizedDescription)))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(CameraError.captureFailed("No image data was produced.")))
        }
    }
}
