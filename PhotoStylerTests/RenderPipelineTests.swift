import CoreImage
import Testing
@testable import PhotoStyler

/// Guards the render pipeline against silent colour drift.
///
/// A regression here does not crash or fail to compile — it just quietly makes
/// every photo look different, which is exactly the kind of change that reaches
/// users unnoticed. These assert on measured pixel values rather than on a
/// stored image, so they stay readable and don't need binary fixtures.
@Suite("Render pipeline")
struct RenderPipelineTests {

    let processor = ImageProcessor()

    /// Mean RGB of a rendered image, 0...1 per channel.
    func meanColour(_ image: CIImage) throws -> SIMD3<Double> {
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: image,
            kCIInputExtentKey: CIVector(cgRect: image.extent),
        ])
        let output = try #require(filter?.outputImage)

        var bytes = [UInt8](repeating: 0, count: 4)
        processor.context.render(
            output,
            toBitmap: &bytes,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
        return SIMD3(Double(bytes[0]) / 255, Double(bytes[1]) / 255, Double(bytes[2]) / 255)
    }

    func profile(_ id: String) async throws -> StyleProfile {
        let profiles = try await BundledProfileRepository().loadProfiles()
        return try #require(profiles.first { $0.id == id }, "no profile \(id)")
    }

    @Test("Original is a genuine pass-through")
    func originalIsPassthrough() throws {
        let source = SampleImage.image
        let out = processor.apply(profile: .original, to: source)
        let before = try meanColour(source)
        let after = try meanColour(out)
        #expect(abs(before.x - after.x) < 0.005)
        #expect(abs(before.y - after.y) < 0.005)
        #expect(abs(before.z - after.z) < 0.005)
    }

    @Test("Zero intensity leaves the image untouched")
    func zeroIntensityIsIdentity() async throws {
        let warm = try await profile("warm-film")
        let source = SampleImage.image
        let out = processor.apply(profile: warm, to: source, intensity: 0)
        let before = try meanColour(source)
        let after = try meanColour(out)
        #expect(abs(before.x - after.x) < 0.005)
        #expect(abs(before.z - after.z) < 0.005)
    }

    @Test("Monochrome desaturates")
    func monochromeIsGrey() async throws {
        let mono = try await profile("monochrome")
        let c = try meanColour(processor.apply(profile: mono, to: SampleImage.image))
        // Channels should converge; the sample image is strongly coloured, so
        // any meaningful spread means the LUT was not applied.
        #expect(abs(c.x - c.y) < 0.03, "R and G differ: \(c)")
        #expect(abs(c.y - c.z) < 0.03, "G and B differ: \(c)")
    }

    @Test("Golden Hour warms the image")
    func goldenHourWarms() async throws {
        let golden = try await profile("golden-hour")
        let before = try meanColour(SampleImage.image)
        let after = try meanColour(processor.apply(profile: golden, to: SampleImage.image))
        // Warming raises red relative to blue.
        #expect((after.x - after.z) > (before.x - before.z), "not warmer: \(before) -> \(after)")
    }

    @Test("Moody Blue cools the image")
    func moodyBlueCools() async throws {
        let moody = try await profile("moody-blue")
        let before = try meanColour(SampleImage.image)
        let after = try meanColour(processor.apply(profile: moody, to: SampleImage.image))
        #expect((after.x - after.z) < (before.x - before.z), "not cooler: \(before) -> \(after)")
    }

    @Test("Airy brightens")
    func airyBrightens() async throws {
        let airy = try await profile("airy")
        let before = try meanColour(SampleImage.image)
        let after = try meanColour(processor.apply(profile: airy, to: SampleImage.image))
        let lumaBefore = 0.2126 * before.x + 0.7152 * before.y + 0.0722 * before.z
        let lumaAfter = 0.2126 * after.x + 0.7152 * after.y + 0.0722 * after.z
        #expect(lumaAfter > lumaBefore, "not brighter: \(lumaBefore) -> \(lumaAfter)")
    }

    @Test("Intensity interpolates between original and full strength")
    func intensityInterpolates() async throws {
        let mono = try await profile("monochrome")
        let source = SampleImage.image
        let full = try meanColour(processor.apply(profile: mono, to: source, intensity: 1))
        let half = try meanColour(processor.apply(profile: mono, to: source, intensity: 0.5))
        let none = try meanColour(processor.apply(profile: mono, to: source, intensity: 0))

        let spread = { (c: SIMD3<Double>) in abs(c.x - c.z) }
        // Half strength should sit between untouched and fully desaturated.
        #expect(spread(half) < spread(none))
        #expect(spread(half) > spread(full) - 0.01)
    }

    @Test("Every profile renders and preserves the source extent")
    func allProfilesRender() async throws {
        for profile in try await BundledProfileRepository().loadProfiles() {
            let out = processor.apply(profile: profile, to: SampleImage.image)
            #expect(out.extent == SampleImage.image.extent, "\(profile.name) changed extent")
            #expect(processor.makeCGImage(out) != nil, "\(profile.name) failed to render")
        }
    }

    @Test("A profile naming a missing LUT degrades instead of failing")
    func missingLUTDegrades() throws {
        let broken = StyleProfile(
            id: "broken", name: "Broken", author: "",
            lutName: "DefinitelyNotThere",
            adjustments: Adjustments(exposure: 0.2)
        )
        let out = processor.apply(profile: broken, to: SampleImage.image)
        // The adjustments still apply; only the lookup is skipped.
        #expect(processor.makeCGImage(out) != nil)
    }

    @Test("Preview scaling shrinks large images and leaves small ones alone")
    func previewScaling() {
        let large = SampleImage.image.transformed(by: .init(scaleX: 8, y: 8))
        let scaled = processor.previewImage(large, maxDimension: 400)
        #expect(max(scaled.extent.width, scaled.extent.height) <= 401)

        let small = processor.previewImage(SampleImage.image, maxDimension: 4000)
        #expect(small.extent == SampleImage.image.extent)
    }

    @Test("Export produces decodable JPEG data")
    func exportsJPEG() async throws {
        let warm = try await profile("warm-film")
        let styled = processor.apply(profile: warm, to: SampleImage.image)
        let data = try #require(processor.jpegData(styled))
        #expect(data.count > 1000)
        // JPEG magic number.
        #expect(data.prefix(2) == Data([0xFF, 0xD8]))
    }
}
