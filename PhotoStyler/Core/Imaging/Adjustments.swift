import Foundation

/// Tunable parameters layered on top of a profile's LUT.
///
/// Every value is centred so that `.neutral` is a genuine no-op: the filter
/// chain skips any stage whose parameters are still at their defaults, which
/// keeps the live preview cheap for profiles that only carry a LUT.
nonisolated struct Adjustments: Codable, Sendable, Hashable {

    /// Exposure in stops. Range -2...2.
    var exposure: Float = 0
    /// Contrast multiplier. 1 is unchanged; useful range 0.5...1.5.
    var contrast: Float = 1
    /// Saturation multiplier. 1 is unchanged, 0 is greyscale.
    var saturation: Float = 1
    /// Warmth, -1 (cool) ... 1 (warm).
    var temperature: Float = 0
    /// Green (-1) ... magenta (1).
    var tint: Float = 0
    /// Highlight recovery, -1 (recover) ... 1 (lift).
    var highlights: Float = 0
    /// Shadow lift, -1 (crush) ... 1 (lift).
    var shadows: Float = 0
    /// Film grain strength, 0...1.
    var grain: Float = 0
    /// Vignette strength, 0...1.
    var vignette: Float = 0
    /// Matte/faded blacks, 0...1.
    var fade: Float = 0

    static let neutral = Adjustments()

    var isNeutral: Bool { self == .neutral }
}

nonisolated extension Adjustments {

    // Decoded key-by-key so a profile's JSON only has to name the parameters it
    // actually changes. Synthesised Codable would require every key present.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value(_ key: CodingKeys, _ fallback: Float) throws -> Float {
            try c.decodeIfPresent(Float.self, forKey: key) ?? fallback
        }
        exposure    = try value(.exposure, 0)
        contrast    = try value(.contrast, 1)
        saturation  = try value(.saturation, 1)
        temperature = try value(.temperature, 0)
        tint        = try value(.tint, 0)
        highlights  = try value(.highlights, 0)
        shadows     = try value(.shadows, 0)
        grain       = try value(.grain, 0)
        vignette    = try value(.vignette, 0)
        fade        = try value(.fade, 0)
    }

    /// Clamps every parameter into its documented range.
    ///
    /// Profiles are data files that may eventually be downloaded, so values are
    /// treated as untrusted: out-of-range input produces odd but bounded output
    /// rather than a broken render.
    func clamped() -> Adjustments {
        var a = self
        a.exposure    = min(max(exposure, -2), 2)
        a.contrast    = min(max(contrast, 0), 2)
        a.saturation  = min(max(saturation, 0), 2)
        a.temperature = min(max(temperature, -1), 1)
        a.tint        = min(max(tint, -1), 1)
        a.highlights  = min(max(highlights, -1), 1)
        a.shadows     = min(max(shadows, -1), 1)
        a.grain       = min(max(grain, 0), 1)
        a.vignette    = min(max(vignette, 0), 1)
        a.fade        = min(max(fade, 0), 1)
        return a
    }
}
