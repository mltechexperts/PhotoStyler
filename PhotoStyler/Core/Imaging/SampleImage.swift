import CoreImage
import CoreImage.CIFilterBuiltins

/// The image the shop renders profile previews from.
///
/// Ships procedurally generated for now: a sky-to-ground gradient crossed with
/// skin-tone, foliage, fabric and neutral patches, chosen because those are the
/// ranges a wedding profile has to get right. Replace with one of Murali's own
/// frames once he picks a frame that is safe to bundle (task 4.7 follow-up) —
/// `SampleImage.image` is the only thing that has to change.
nonisolated enum SampleImage {

    static let size = CGSize(width: 480, height: 640)

    /// Patches laid over the gradient, top-left to bottom-right.
    private static let patches: [(CIColor, CGRect)] = [
        // Skin tones: light, mid, deep.
        (CIColor(red: 0.96, green: 0.80, blue: 0.69), CGRect(x: 40,  y: 400, width: 120, height: 120)),
        (CIColor(red: 0.80, green: 0.58, blue: 0.45), CGRect(x: 180, y: 400, width: 120, height: 120)),
        (CIColor(red: 0.45, green: 0.29, blue: 0.21), CGRect(x: 320, y: 400, width: 120, height: 120)),
        // Foliage and florals.
        (CIColor(red: 0.24, green: 0.38, blue: 0.20), CGRect(x: 40,  y: 260, width: 120, height: 120)),
        (CIColor(red: 0.72, green: 0.22, blue: 0.28), CGRect(x: 180, y: 260, width: 120, height: 120)),
        // A white dress: the highlight detail every wedding profile must hold.
        (CIColor(red: 0.97, green: 0.96, blue: 0.94), CGRect(x: 320, y: 260, width: 120, height: 120)),
        // Neutral ramp for judging contrast and colour cast.
        (CIColor(red: 0.05, green: 0.05, blue: 0.05), CGRect(x: 40,  y: 120, width: 100, height: 120)),
        (CIColor(red: 0.35, green: 0.35, blue: 0.35), CGRect(x: 150, y: 120, width: 100, height: 120)),
        (CIColor(red: 0.65, green: 0.65, blue: 0.65), CGRect(x: 260, y: 120, width: 100, height: 120)),
        (CIColor(red: 0.92, green: 0.92, blue: 0.92), CGRect(x: 370, y: 120, width: 70,  height: 120)),
    ]

    static let image: CIImage = {
        let extent = CGRect(origin: .zero, size: size)

        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: 0, y: size.height)
        gradient.color0 = CIColor(red: 0.42, green: 0.60, blue: 0.82)   // sky
        gradient.point1 = CGPoint(x: 0, y: 0)
        gradient.color1 = CIColor(red: 0.86, green: 0.74, blue: 0.58)   // warm ground
        var result = (gradient.outputImage ?? CIImage(color: .gray)).cropped(to: extent)

        for (color, rect) in patches {
            let patch = CIImage(color: color).cropped(to: rect)
            result = patch.composited(over: result)
        }
        return result.cropped(to: extent)
    }()
}
