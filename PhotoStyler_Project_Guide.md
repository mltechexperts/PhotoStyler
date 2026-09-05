# PhotoStyler — iPhone App Project Guide

**Author:** Murali (ML Creative Studios)
**Started:** September 2026
**Status:** Phase 1 — Setup & Learning
**App Type:** Photography / Camera + Filters
**Platform:** iOS (iPhone) using SwiftUI

---

## 🎯 App Vision

A personal photography app that combines a **custom camera interface** with **photo filters and effects**, eventually incorporating **AI-powered style transfer** trained on Murali's own wedding photography editing style.

### Core Features (Planned)
- Custom camera UI with live viewfinder
- Photo filter presets (warm film, moody editorial, bright airy, etc.)
- Live preview of filters before capturing
- Gallery of filtered photos
- AI style transfer trained on personal editing style (Phase 2)

---

## 📋 Project Roadmap

| Phase | What | Timeline | Status |
|-------|------|----------|--------|
| 1 | Set up tools (Xcode, project) | Day 1 | ✅ Done |
| 2 | Learn SwiftUI basics | Week 1–2 | 🔄 In Progress |
| 3 | Build custom camera | Week 3–4 | ⬜ Not Started |
| 4 | Add photo filters & presets | Week 5–6 | ⬜ Not Started |
| 5 | Polish & test on iPhone | Week 7–8 | ⬜ Not Started |
| 6 | AI style transfer (Phase 2) | Month 3+ | ⬜ Future |

---

## 🛠 Tools & Setup

### Required Software
- **Xcode** — Free from Mac App Store (~12GB download, ~40GB installed)
- **macOS** — Sequoia 15.6 or later
- **Apple Developer Account** — Free for development/testing, $99/year for App Store

### Project Settings
- **Project Name:** PhotoStyler
- **Organization Identifier:** com.mlcreativestudios
- **Interface:** SwiftUI
- **Language:** Swift

### Required Permissions (Info.plist)
Add these under **Custom iOS Target Properties** in the Info tab:

| Key | Value |
|-----|-------|
| Privacy - Camera Usage Description | PhotoStyler needs camera access to take photos |
| Privacy - Photo Library Usage Description | PhotoStyler needs photo library access to save your photos |

---

## 📁 Project File Structure

```
PhotoStyler/
├── PhotoStylerApp.swift          (auto-generated, app entry point)
├── ContentView.swift             (home screen with camera & gallery buttons)
├── CameraManager.swift           (camera hardware engine — AVFoundation)
├── CameraView.swift              (camera UI — viewfinder, shutter, controls)
├── Assets.xcassets               (app icons, colors, images)
└── Preview Content/              (preview assets for Xcode canvas)
```

---

## 💻 Source Code

### ContentView.swift
The home screen with navigation to camera and gallery.

```swift
import SwiftUI

struct ContentView: View {
    @State private var showCamera = false
    @State private var showGallery = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                
                Spacer()
                
                // App title
                VStack(spacing: 8) {
                    Text("PhotoStyler")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    
                    Text("Capture. Style. Create.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Camera button
                Button(action: {
                    showCamera = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Open Camera")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                // Gallery button
                Button(action: {
                    showGallery = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                        Text("My Photos")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                
                Spacer()
                
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
        }
    }
}

#Preview {
    ContentView()
}
```

---

### CameraManager.swift
The engine that connects to iPhone camera hardware.

```swift
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
```

---

### CameraView.swift
The camera UI — viewfinder, shutter button, flash, and camera flip.

```swift
import SwiftUI

struct CameraView: View {
    @StateObject private var camera = CameraManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showCapturedPhoto = false
    
    var body: some View {
        ZStack {
            // Live camera preview (fills the whole screen)
            Color.black.ignoresSafeArea()
            
            if camera.isCameraReady {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            }
            
            // Camera controls overlay
            VStack {
                
                // Top bar: Close, Flash
                HStack {
                    // Close button
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    
                    Spacer()
                    
                    // Flash toggle
                    Button(action: { camera.toggleFlash() }) {
                        Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title3)
                            .foregroundColor(camera.isFlashOn ? .yellow : .white)
                            .padding(12)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Bottom bar: Gallery preview, Shutter, Flip camera
                HStack(spacing: 40) {
                    
                    // Recent photo thumbnail
                    if let image = camera.recentImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.white, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)
                    }
                    
                    // Shutter button
                    Button(action: {
                        camera.capturePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 82, height: 82)
                        }
                    }
                    
                    // Flip camera button
                    Button(action: { camera.flipCamera() }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
    }
}

#Preview {
    CameraView()
}
```

---

## 🧠 Key SwiftUI Concepts to Know

| Concept | What it does | Example |
|---------|-------------|---------|
| `VStack` | Stacks things vertically | Title above button |
| `HStack` | Stacks things horizontally | Icon next to text |
| `ZStack` | Layers things on top of each other | Controls over camera |
| `@State` | A value the view remembers and reacts to | `showCamera = true` |
| `@Published` | Like @State but for shared classes | Camera ready status |
| `@StateObject` | Creates and owns a shared object | CameraManager instance |
| `NavigationStack` | Enables screen-to-screen navigation | Home → Camera |
| `.fullScreenCover` | Presents a view covering the full screen | Camera over home |
| `Image(systemName:)` | Uses Apple's built-in SF Symbols icons | camera.fill, bolt.fill |

---

## 🔧 Troubleshooting

### Build Failed — "Cannot find CameraView/CameraManager"
This means the file isn't linked to your project target.
1. Click on the file in the left sidebar
2. Open right sidebar (⌥ + Cmd + 1)
3. Under **Target Membership**, check the **PhotoStyler** box
4. Repeat for all .swift files

### Camera shows black screen in Simulator
This is expected — the Simulator doesn't have a real camera. Deploy to your physical iPhone to test the camera.

### How to run on your iPhone
1. Connect iPhone via USB cable
2. In the device selector (top of Xcode), choose your iPhone
3. You may need to trust the device: on iPhone go to Settings → General → VPN & Device Management
4. Press Play (▶) or Cmd + R

---

## 📅 Next Steps

- [ ] Fix build errors and get the home screen running
- [ ] Get the camera view working (test on real iPhone)
- [ ] Build photo filter presets (Phase 4 — CIFilter / Core Image)
- [ ] Add filter picker UI with live preview thumbnails
- [ ] Add photo gallery view
- [ ] Polish UI — app icon, launch screen, animations
- [ ] Phase 2: Train AI style transfer model with Create ML
- [ ] Phase 2: Integrate Core ML model into the app

---

## 💡 Style Transfer Plan (Phase 2)

### Approach: Start with presets, add AI later

**Manual Presets (Phase 1):**
- Use Apple's `CIFilter` framework for image processing
- Create preset combinations for signature styles (warm film, moody editorial, bright airy)
- Add adjustable intensity slider per filter

**AI Style Transfer (Phase 2):**
- Use Apple's **Create ML** to train a style transfer model
- Feed before/after pairs from wedding photography portfolio
- Export as `.mlmodel` file
- Integrate into app using **Core ML** framework
- Add a "My Style" button that applies learned editing aesthetic

---

## 📝 Cost Summary

| Item | Cost |
|------|------|
| Xcode | Free |
| Apple Developer Account (testing only) | Free |
| Apple Developer Program (App Store) | $99/year |
| iPhone Simulator testing | Free |
| Create ML (AI training) | Free |
| **Total to build & test** | **$0** |

---

*Last updated: September 5, 2026*
*Guide created with help from Claude (Anthropic)*
