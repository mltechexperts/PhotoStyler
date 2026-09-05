import SwiftData
import SwiftUI

struct GalleryView: View {
    @Query(sort: \CapturedPhoto.capturedAt, order: .reverse)
    private var photos: [CapturedPhoto]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var selected: CapturedPhoto?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 3)]

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    ContentUnavailableView {
                        Label("No Photos Yet", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Photos you take in PhotoStyler appear here, with the style you used.")
                    }
                } else {
                    grid
                }
            }
            .navigationTitle("My Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selected) { photo in
                PhotoDetailView(photo: photo, onDelete: { delete(photo) })
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(photos) { photo in
                    Button { selected = photo } label: {
                        GalleryThumbnail(photo: photo)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 3)
        }
    }

    private func delete(_ photo: CapturedPhoto) {
        PhotoStore.delete(photo.fileName)
        context.delete(photo)
        selected = nil
    }
}

private struct GalleryThumbnail: View {
    let photo: CapturedPhoto
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            if !photo.profileName.isEmpty {
                Text(photo.profileName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .padding(5)
            }
        }
        .task(id: photo.fileName) {
            image = await Self.load(photo.fileURL)
        }
        .accessibilityLabel("Photo styled with \(photo.profileName)")
    }

    /// Downsampled off the main actor; full-size decoding of a grid of photos
    /// would stall scrolling.
    private static func load(_ url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 400,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: cg)
        }.value
    }
}

private struct PhotoDetailView: View {
    let photo: CapturedPhoto
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().frame(maxHeight: .infinity)
                }

                VStack(spacing: 4) {
                    Text(photo.profileName.isEmpty ? "Original" : photo.profileName)
                        .font(.headline)
                    Text(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if photo.intensity < 1 {
                        Text("Intensity \(Int(photo.intensity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete", role: .destructive) { confirmingDelete = true }
                }
            }
            .confirmationDialog(
                "Delete this photo?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: onDelete)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes it from PhotoStyler. The copy in your photo library is not affected.")
            }
            .task {
                // Read the path on the main actor: CapturedPhoto is a SwiftData
                // model and must not cross into the detached task.
                let path = photo.fileURL.path
                image = await Task.detached(priority: .userInitiated) {
                    UIImage(contentsOfFile: path)
                }.value
            }
        }
    }
}
