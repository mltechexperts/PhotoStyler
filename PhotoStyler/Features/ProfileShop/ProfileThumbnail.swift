import SwiftUI

/// Async-rendered preview of a profile, with a placeholder while it renders.
struct ProfileThumbnail: View {
    let profile: StyleProfile
    var maxDimension: CGFloat = 400

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .animation(.easeOut(duration: 0.2), value: image != nil)
        .task(id: profile.id) {
            image = await ThumbnailRenderer.shared.thumbnail(
                for: profile, maxDimension: maxDimension
            )
        }
    }
}
