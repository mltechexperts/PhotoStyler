import CoreImage
import CoreImage.CIFilterBuiltins
import Metal
import OSLog

/// Builds and renders the Core Image chain for a style profile.
///
/// One shared instance owns the `CIContext`: contexts are expensive to create
/// and cache compiled shaders internally, so per-frame or per-view contexts
/// would stall the live preview.
nonisolated final class ImageProcessor: @unchecked Sendable {

    static let shared = ImageProcessor()

    private static let logger = Logger(subsystem: "com.mlcreativestudios.PhotoStyler", category: "imaging")

    let context: CIContext
    private let lutStore: LUTStore

    init(lutStore: LUTStore = .shared) {
        self.lutStore = lutStore
        if let device = MTLCreateSystemDefaultDevice() {
            // cacheIntermediates: false keeps memory flat while streaming video
            // frames; the chain is short enough that re-evaluation is cheaper
            // than retaining intermediates.
            context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        } else {
            Self.logger.warning("No Metal device; falling back to a software CIContext")
            context = CIContext(options: [.cacheIntermediates: false])
        }
    }

    // MARK: - Chain

    /// Applies `profile` to `image` at `intensity` (0 = untouched, 1 = full).
    ///
    /// Returns a `CIImage`, which is a recipe rather than pixels — nothing is
    /// computed until the result is rendered.
    func apply(
        profile: StyleProfile,
        to image: CIImage,
        intensity: Float = 1
    ) -> CIImage {
        guard !profile.isOriginal, intensity > 0 else { return image }

        let styled = style(image, with: profile)
        guard intensity < 1 else { return styled }

        // CIMix blends the styled recipe back toward the original, which is how
        // the intensity slider stays a single cheap parameter rather than a
        // re-render of the whole chain.
        let mix = CIFilter.mix()
        mix.inputImage = styled
        mix.backgroundImage = image
        mix.amount = intensity
        return (mix.outputImage ?? styled).cropped(to: image.extent)
    }

    private func style(_ image: CIImage, with profile: StyleProfile) -> CIImage {
        let a = profile.adjustments.clamped()
        var out = image

        // Tone and colour first, so the LUT grades an already-normalised image —
        // the same order a Lightroom edit applies before its profile.
        if a.exposure != 0 {
            let f = CIFilter.exposureAdjust()
            f.inputImage = out
            f.ev = a.exposure
            out = f.outputImage ?? out
        }

        if a.temperature != 0 || a.tint != 0 {
            let f = CIFilter.temperatureAndTint()
            f.inputImage = out
            f.neutral = CIVector(x: 6500, y: 0)
            // Both axes are inverted relative to how the parameters read:
            // CITemperatureAndTint adapts the image *from* `neutral` *to*
            // `targetNeutral`, so a lower target temperature warms the image
            // and a negative target tint pushes magenta. ±1 maps to roughly
            // ±1500K, a strong but not destructive shift.
            f.targetNeutral = CIVector(x: CGFloat(6500 - a.temperature * 1500),
                                       y: CGFloat(-a.tint * 50))
            out = f.outputImage ?? out
        }

        if a.highlights != 0 || a.shadows != 0 {
            let f = CIFilter.highlightShadowAdjust()
            f.inputImage = out
            f.highlightAmount = 1 + a.highlights
            f.shadowAmount = a.shadows
            out = f.outputImage ?? out
        }

        if a.contrast != 1 || a.saturation != 1 {
            let f = CIFilter.colorControls()
            f.inputImage = out
            f.contrast = a.contrast
            f.saturation = a.saturation
            f.brightness = 0
            out = f.outputImage ?? out
        }

        if let lutName = profile.lutName {
            out = applyLUT(named: lutName, to: out)
        }

        if a.fade > 0 { out = applyFade(a.fade, to: out) }
        if a.grain > 0 { out = applyGrain(a.grain, to: out) }

        if a.vignette > 0 {
            let f = CIFilter.vignette()
            f.inputImage = out
            f.intensity = a.vignette
            f.radius = 1.5
            out = f.outputImage ?? out
        }

        return out.cropped(to: image.extent)
    }

    // MARK: - Stages

    private func applyLUT(named name: String, to image: CIImage) -> CIImage {
        do {
            let lut = try lutStore.lut(named: name)
            let f = CIFilter.colorCubeWithColorSpace()
            f.inputImage = image
            f.cubeDimension = Float(lut.dimension)
            f.cubeData = lut.data
            f.colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
            return f.outputImage ?? image
        } catch {
            // A missing or malformed LUT degrades to the ungraded image rather
            // than failing the capture.
            Self.logger.error("LUT \(name, privacy: .public) unavailable: \(error.localizedDescription, privacy: .public)")
            return image
        }
    }

    /// Lifts the blacks toward a matte, film-print finish.
    private func applyFade(_ amount: Float, to image: CIImage) -> CIImage {
        let lift = CGFloat(amount) * 0.18
        let f = CIFilter.toneCurve()
        f.inputImage = image
        f.point0 = CGPoint(x: 0, y: lift)
        f.point1 = CGPoint(x: 0.25, y: 0.25 + lift * 0.6)
        f.point2 = CGPoint(x: 0.5, y: 0.5 + lift * 0.3)
        f.point3 = CGPoint(x: 0.75, y: 0.75 + lift * 0.1)
        f.point4 = CGPoint(x: 1, y: 1)
        return f.outputImage ?? image
    }

    /// Monochrome noise composited in soft light, so grain reads as texture
    /// rather than coloured speckle.
    private func applyGrain(_ amount: Float, to image: CIImage) -> CIImage {
        guard let noise = CIFilter.randomGenerator().outputImage else { return image }

        let mono = CIFilter.colorControls()
        mono.inputImage = noise.cropped(to: image.extent)
        mono.saturation = 0
        mono.brightness = 0
        mono.contrast = 1
        guard let grey = mono.outputImage else { return image }

        let faded = grey.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(amount) * 0.25),
        ])

        let blend = CIFilter.softLightBlendMode()
        blend.inputImage = faded
        blend.backgroundImage = image
        return blend.outputImage?.cropped(to: image.extent) ?? image
    }

    // MARK: - Rendering

    /// Downscales for the live preview and the shop grid.
    ///
    /// Rendering the full sensor image every frame is what makes a styled
    /// viewfinder drop frames; the export path below is the one that runs at
    /// full resolution.
    func previewImage(_ image: CIImage, maxDimension: CGFloat) -> CIImage {
        let longest = max(image.extent.width, image.extent.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        return image.transformed(by: .init(scaleX: scale, y: scale))
    }

    /// Renders to a `CGImage`. Call off the main thread.
    func makeCGImage(_ image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }

    /// Full-quality JPEG for export, tagged sRGB so colours survive the trip to
    /// the photo library. `properties` carries the source EXIF through, so the
    /// saved file keeps its capture date, lens and exposure.
    func jpegData(
        _ image: CIImage,
        quality: Float = 0.95,
        properties: [String: Any] = [:]
    ) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var options: [CIImageRepresentationOption: Any] = [
            kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality,
        ]
        if let exif = properties[kCGImagePropertyExifDictionary as String] {
            options[kCGImagePropertyExifDictionary as CIImageRepresentationOption] = exif
        }
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] {
            options[kCGImagePropertyTIFFDictionary as CIImageRepresentationOption] = tiff
        }
        return context.jpegRepresentation(of: image, colorSpace: colorSpace, options: options)
    }
}
