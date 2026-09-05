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
