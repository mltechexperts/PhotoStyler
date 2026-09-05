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

