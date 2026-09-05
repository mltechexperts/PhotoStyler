import SwiftUI

struct ProfileDetailView: View {
    let profile: StyleProfile

    @State private var intensity: Float = 1
    @State private var dividerFraction: CGFloat = 0.5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BeforeAfterCompare(
                        profile: profile,
                        intensity: intensity,
                        fraction: $dividerFraction
                    )
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    intensityControl

                    if !profile.summary.isEmpty {
                        Text(profile.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }

                    if !profile.tags.isEmpty {
                        tagRow
                    }

                    detailRows
                }
                .padding(.vertical, 12)
            }
            .navigationTitle(profile.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var intensityControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Intensity").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(intensity * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $intensity, in: 0...1)
                .accessibilityLabel("Style intensity")
                .accessibilityValue("\(Int(intensity * 100)) percent")
        }
        .padding(.horizontal, 16)
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(profile.tags) { tag in
                    Text(tag.displayName)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var detailRows: some View {
        VStack(spacing: 0) {
            if !profile.author.isEmpty {
                LabeledContent("Author", value: profile.author)
                Divider()
            }
            LabeledContent("Colour", value: profile.lutName == nil ? "Adjustments only" : "3D LUT")
        }
        .font(.subheadline)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal, 16)
    }
}

/// Original on the left of the divider, styled on the right; drag to move it.
private struct BeforeAfterCompare: View {
    let profile: StyleProfile
    let intensity: Float
    @Binding var fraction: CGFloat

    @State private var styled: UIImage?
    @State private var original: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color(.secondarySystemBackground)

                if let original {
                    Image(uiImage: original).resizable().scaledToFill()
                }

                if let styled {
                    Image(uiImage: styled)
                        .resizable()
                        .scaledToFill()
                        // Reveal the styled version to the right of the divider.
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: geo.size.width * (1 - fraction))
                        }
                }

                if styled == nil || original == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                divider(in: geo.size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        fraction = min(max(value.location.x / geo.size.width, 0), 1)
                    }
            )
            .clipped()
        }
        .task(id: profile.id) { await renderOriginal() }
        .task(id: renderKey) { await renderStyled() }
    }

    /// Re-render only when the profile or a meaningful intensity step changes;
    /// every slider pixel would otherwise queue a full-chain render.
    private var renderKey: String { "\(profile.id)-\(Int(intensity * 20))" }

    private func divider(in size: CGSize) -> some View {
        let x = size.width * fraction
        return ZStack {
            Rectangle()
                .fill(.white)
                .frame(width: 2)
                .shadow(radius: 2)
            Circle()
                .fill(.white)
                .frame(width: 34, height: 34)
                .shadow(radius: 3)
                .overlay {
                    Image(systemName: "arrow.left.and.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                }
        }
        .position(x: x, y: size.height / 2)
        .accessibilityHidden(true)
    }

    private func renderOriginal() async {
        original = await ThumbnailRenderer.shared.thumbnail(
            for: .original, maxDimension: 900
        )
    }

    private func renderStyled() async {
        let processor = ImageProcessor.shared
        let value = intensity
        let profile = profile
        styled = await Task.detached(priority: .userInitiated) {
            let source = processor.previewImage(SampleImage.image, maxDimension: 900)
            let output = processor.apply(profile: profile, to: source, intensity: value)
            return processor.makeCGImage(output).map { UIImage(cgImage: $0) }
        }.value
    }
}

#Preview {
    ProfileDetailView(
        profile: StyleProfile(
            id: "preview", name: "Warm Film", author: "ML Creative Studios",
            summary: "Warm negative stock with lifted blacks.",
            tags: [.film, .warm], lutName: nil,
            adjustments: Adjustments(exposure: 0.1, temperature: 0.3, fade: 0.2)
        )
    )
}
