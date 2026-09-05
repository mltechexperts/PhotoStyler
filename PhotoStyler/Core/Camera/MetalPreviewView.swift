import CoreImage
import MetalKit
import SwiftUI

/// Draws filtered camera frames.
///
/// `AVCaptureVideoPreviewLayer` renders raw sensor output straight to the
/// screen and no Core Image filter can be inserted into it, so a styled
/// viewfinder has to own its drawing. Frames arrive on the capture queue and
/// are rendered straight into the Metal drawable from there — hopping to the
/// main actor per frame would both stutter and pile up latency.
/// Holds the newest frame until the main actor can draw it.
///
/// Frames arrive on the capture queue while `MTKView` is main-actor bound, so
/// they are handed over through this box rather than by touching the view from
/// the wrong thread. Only the newest frame is kept: if drawing falls behind,
/// stale frames are dropped instead of queueing latency.
private nonisolated final class FrameBox: @unchecked Sendable {
    private let lock = NSLock()
    private var image: CIImage?
    private var isScheduled = false

    /// Stores `newImage`; returns true when the caller should schedule a draw.
    func store(_ newImage: CIImage) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        image = newImage
        guard !isScheduled else { return false }
        isScheduled = true
        return true
    }

    func take() -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        isScheduled = false
        let taken = image
        image = nil
        return taken
    }
}

final class MetalPreviewView: MTKView {

    private let ciContext: CIContext
    private let commandQueue: (any MTLCommandQueue)?
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    private nonisolated let frames = FrameBox()

    init(processor: ImageProcessor = .shared) {
        let device = MTLCreateSystemDefaultDevice()
        self.ciContext = processor.context
        self.commandQueue = device?.makeCommandQueue()
        super.init(frame: .zero, device: device)

        framebufferOnly = false          // Core Image renders into the texture
        isPaused = true                  // driven by frame arrival, not a clock
        enableSetNeedsDisplay = false
        autoResizeDrawable = true
        isOpaque = true
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Submits a frame. Safe to call from any queue.
    nonisolated func enqueue(_ image: CIImage) {
        guard frames.store(image) else { return }
        Task { @MainActor [weak self] in
            self?.drawPendingFrame()
        }
    }

    private func drawPendingFrame() {
        guard let image = frames.take() else { return }
        let size = drawableSize
        guard size.width > 0, size.height > 0 else { return }
        render(image, drawableSize: size)
    }

    private func render(_ image: CIImage, drawableSize size: CGSize) {
        guard let commandQueue,
              let colorSpace,
              let drawable = currentDrawable,
              let buffer = commandQueue.makeCommandBuffer() else { return }

        ciContext.render(
            aspectFill(image, in: size),
            to: drawable.texture,
            commandBuffer: buffer,
            bounds: CGRect(origin: .zero, size: size),
            colorSpace: colorSpace
        )
        buffer.present(drawable)
        buffer.commit()
    }

    /// Scales to cover and centre-crops, matching `.resizeAspectFill`.
    private func aspectFill(_ image: CIImage, in size: CGSize) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return image }

        let scale = max(size.width / extent.width, size.height / extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = scaled.extent.origin.x + (scaled.extent.width - size.width) / 2
        let dy = scaled.extent.origin.y + (scaled.extent.height - size.height) / 2
        return scaled.transformed(by: CGAffineTransform(translationX: -dx, y: -dy))
    }
}

/// SwiftUI wrapper. The view is created once and handed to the controller so
/// frames can be pushed into it directly.
struct MetalCameraPreview: UIViewRepresentable {
    let controller: CameraController
    var onTap: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> MetalPreviewView {
        let view = MetalPreviewView()
        controller.attachPreview(view)

        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        context.coordinator.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: MetalPreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onTap: ((CGPoint) -> Void)?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)
            // Normalised to the view; the controller converts to device space,
            // since only it knows the active format's aspect.
            onTap?(CGPoint(
                x: location.x / max(view.bounds.width, 1),
                y: location.y / max(view.bounds.height, 1)
            ))
        }
    }
}
