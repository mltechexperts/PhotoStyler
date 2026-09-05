import AVFoundation
import SwiftUI

/// Hosts the capture preview.
///
/// The backing view returns `AVCaptureVideoPreviewLayer` from `layerClass`, so
/// UIKit sizes the layer with the view automatically. The original version
/// added a sublayer and set its frame from `UIScreen.main.bounds` — deprecated
/// in iOS 26, and wrong on any screen the view does not fill.
final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Safe by construction: layerClass above guarantees the type.
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Reports a tap as (capture-device point, layer point). The conversion
    /// happens here because only the preview layer knows the mapping; the layer
    /// point is passed through so the UI can draw the focus indicator.
    var onTap: ((CGPoint, CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black

        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        context.coordinator.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.session !== session { uiView.session = session }
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onTap: ((CGPoint, CGPoint) -> Void)?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? PreviewUIView else { return }
            let location = recognizer.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: location)
            onTap?(devicePoint, location)
        }
    }
}
