import SwiftUI
import AVFoundation
import Photos

// This class manages the actual camera hardware
class CameraManager: NSObject, ObservableObject {
    
    // The capture session connects the camera input to our preview output
    let session = AVCaptureSession()
    
    // Published properties automatically update the UI when they change
    @Published var recentImage: UIImage?
    @Published var isCameraReady = false
    @Published var isUsingFrontCamera = false
    @Published var isFlashOn = false
    
    private let output = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    
    override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add camera input
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else { return }
        
        currentDevice = device
        
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Add photo output
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        
        // Start the camera on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isCameraReady = true
            }
        }
    }
    
    // MARK: - Actions
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
        // Turn on flash if enabled and available
        if isFlashOn {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func flipCamera() {
        session.beginConfiguration()
        
        // Remove current input
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
        }
        
        // Switch camera position
        isUsingFrontCamera.toggle()
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        
        guard let newDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: newPosition
        ) else {
            session.commitConfiguration()
            return
        }
        
        currentDevice = newDevice
        
        guard let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(newInput) {
            session.addInput(newInput)
        }
        
        session.commitConfiguration()
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.recentImage = image
        }
        
        // Save to photo library
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset()
                    .addResource(with: .photo, data: data, options: nil)
            }
        }
    }
}

// MARK: - Camera Preview

// This bridges AVFoundation's camera preview into SwiftUI
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

