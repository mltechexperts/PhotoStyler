import CoreImage
import OSLog
import UIKit

/// Renders and caches the small preview shown on each profile card.
///
/// The shop grid re-asks for these on every scroll, and each render walks the
/// whole filter chain including a 33-cube lookup, so uncached rendering visibly
/// stutters. Cached by profile id plus pixel size.
nonisolated final class ThumbnailRenderer: @unchecked Sendable {

    static let shared = ThumbnailRenderer()

    private let processor: ImageProcessor
    private let cache = NSCache<NSString, UIImage>()

    init(processor: ImageProcessor = .shared) {
        self.processor = processor
        // Roughly 80 thumbnails at 300x400; NSCache evicts under pressure.
        cache.countLimit = 80
    }

    /// Renders `profile` applied to `source`, off the main actor.
    func thumbnail(
        for profile: StyleProfile,
        source: CIImage = SampleImage.image,
        maxDimension: CGFloat = 400
    ) async -> UIImage? {
        let key = "\(profile.id)-\(Int(maxDimension))" as NSString
        if let hit = cache.object(forKey: key) { return hit }

        let rendered = await Task.detached(priority: .userInitiated) { [processor] in
            let scale = min(
                maxDimension / source.extent.width,
                maxDimension / source.extent.height,
                1
            )
            let scaled = source.transformed(by: .init(scaleX: scale, y: scale))
            let styled = processor.apply(profile: profile, to: scaled)
            return processor.makeCGImage(styled).map { UIImage(cgImage: $0) }
        }.value

        if let rendered { cache.setObject(rendered, forKey: key) }
        return rendered
    }

    func clear() { cache.removeAllObjects() }
}
