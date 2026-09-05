import AVFoundation
import SwiftUI

struct CameraView: View {
    @State private var camera = CameraModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.phase {
            case .running:
                viewfinder
            case .denied:
                CameraUnavailableView(
                    icon: "lock.fill",
                    title: "Camera Access Needed",
                    message: "Allow camera access in Settings to take photos with PhotoStyler.",
                    actionTitle: "Open Settings",
                    action: camera.openSettings
                )
            case .failed(let message):
                CameraUnavailableView(
                    icon: "exclamationmark.triangle.fill",
                    title: "Camera Unavailable",
                    message: message,
                    actionTitle: nil,
                    action: nil
                )
            case .idle, .preparing:
                ProgressView().tint(.white)
            }

            controls
        }
        .animation(.easeInOut(duration: 0.2), value: camera.phase)
        .task { await camera.onAppear() }
        .onDisappear { Task { await camera.onDisappear() } }
        .statusBarHidden()
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        CameraPreview(session: camera.session) { devicePoint, layerPoint in
            Task { await camera.focus(at: devicePoint, layerPoint: layerPoint) }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            if let point = camera.focusIndicator {
                FocusIndicator()
                    .position(point)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: camera.focusIndicator)
        .gesture(zoomGesture)
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                camera.zoom = min(max(camera.zoom * value.magnification, 1), camera.controller.maxZoomFactor)
            }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            topBar
            Spacer()
            if let error = camera.transientError {
                ErrorBanner(message: error, dismiss: camera.dismissError)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if camera.phase == .running { bottomBar }
        }
        .animation(.spring(duration: 0.3), value: camera.transientError)
    }

    private var topBar: some View {
        HStack {
            CircleButton(systemName: "xmark", action: { dismiss() })
                .accessibilityLabel("Close camera")

            Spacer()

            // Hidden rather than disabled on the front camera: there is no flash
            // unit there, so the control has nothing to mean.
            if camera.isFlashSupported {
                CircleButton(
                    systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                    tint: camera.isFlashOn ? .yellow : .white,
                    action: { camera.isFlashOn.toggle() }
                )
                .accessibilityLabel(camera.isFlashOn ? "Turn flash off" : "Turn flash on")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var bottomBar: some View {
        HStack(spacing: 40) {
            thumbnail
            shutter
            CircleButton(systemName: "camera.rotate.fill", action: {
                Task { await camera.flipCamera() }
            })
            .accessibilityLabel("Switch camera")
        }
        .padding(.bottom, 40)
    }

    private var thumbnail: some View {
        Group {
            if let image = camera.recentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.2)
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.8), lineWidth: 1))
        .accessibilityLabel("Most recent photo")
    }

    private var shutter: some View {
        Button {
            Task { await camera.capture() }
        } label: {
            ZStack {
                Circle().fill(.white).frame(width: 72, height: 72)
                Circle().stroke(.white, lineWidth: 4).frame(width: 82, height: 82)
                if camera.isCapturing {
                    ProgressView().tint(.black)
                }
            }
            .scaleEffect(camera.isCapturing ? 0.92 : 1)
            .animation(.spring(duration: 0.2), value: camera.isCapturing)
        }
        .disabled(camera.isCapturing)
        .accessibilityLabel("Take photo")
    }
}

// MARK: - Pieces

private struct CircleButton: View {
    let systemName: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.ultraThinMaterial))
        }
    }
}

private struct FocusIndicator: View {
    @State private var scale: CGFloat = 1.4

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(.yellow, lineWidth: 1.5)
            .frame(width: 72, height: 72)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) { scale = 1 }
            }
            .allowsHitTesting(false)
    }
}

private struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(message).font(.footnote)
            Spacer(minLength: 0)
            Button("Dismiss", action: dismiss).font(.footnote.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.red.opacity(0.85)))
    }
}

private struct CameraUnavailableView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.8))
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
    }
}

#Preview {
    CameraView()
}
