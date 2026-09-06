import Foundation
import Testing
@testable import PhotoStyler

/// The parser reads untrusted data — LUTs become downloadable under D4 — so
/// malformed input must fail cleanly rather than crash or render garbage.
@Suite("Cube LUT parsing")
struct CubeLUTTests {

    /// A valid 2×2×2 identity cube: 8 entries, red varying fastest.
    static let identity2 = """
        # a comment
        TITLE "Identity"
        LUT_3D_SIZE 2
        DOMAIN_MIN 0.0 0.0 0.0
        DOMAIN_MAX 1.0 1.0 1.0
        0.0 0.0 0.0
        1.0 0.0 0.0
        0.0 1.0 0.0
        1.0 1.0 0.0
        0.0 0.0 1.0
        1.0 0.0 1.0
        0.0 1.0 1.0
        1.0 1.0 1.0
        """

    @Test("Parses a well-formed cube")
    func parsesIdentity() throws {
        let lut = try CubeLUTParser.parse(Self.identity2)
        #expect(lut.dimension == 2)
        #expect(lut.title == "Identity")
        #expect(lut.domainMin == SIMD3<Float>(0, 0, 0))
        #expect(lut.domainMax == SIMD3<Float>(1, 1, 1))
        // 8 texels x RGBA x 4 bytes
        #expect(lut.data.count == 8 * 4 * MemoryLayout<Float>.size)
    }

    @Test("Ignores comments and blank lines")
    func ignoresNoise() throws {
        let noisy = Self.identity2
            .replacingOccurrences(of: "LUT_3D_SIZE 2", with: "\n# note\n\nLUT_3D_SIZE 2\n")
        #expect(try CubeLUTParser.parse(noisy).dimension == 2)
    }

    @Test("Rejects a cube with no declared size")
    func rejectsMissingSize() {
        let text = "0.0 0.0 0.0\n1.0 1.0 1.0"
        #expect(throws: LUTError.missingSize) {
            try CubeLUTParser.parse(text)
        }
    }

    @Test("Rejects 1D LUTs")
    func rejects1D() {
        #expect(throws: LUTError.unsupported1DLUT) {
            try CubeLUTParser.parse("LUT_1D_SIZE 16\n0.0 0.0 0.0")
        }
    }

    @Test("Rejects sizes outside the supported range", arguments: [1, 0, 129, 4096])
    func rejectsBadSize(_ size: Int) {
        #expect(throws: LUTError.unsupportedSize(size)) {
            try CubeLUTParser.parse("LUT_3D_SIZE \(size)\n0.0 0.0 0.0")
        }
    }

    @Test("Rejects a truncated cube")
    func rejectsTruncated() {
        let truncated = """
            LUT_3D_SIZE 2
            0.0 0.0 0.0
            1.0 0.0 0.0
            """
        #expect(throws: LUTError.entryCountMismatch(expected: 8, found: 2)) {
            try CubeLUTParser.parse(truncated)
        }
    }

    @Test("Rejects a non-numeric entry")
    func rejectsGarbage() {
        let bad = "LUT_3D_SIZE 2\n0.0 0.0 0.0\nnot a colour\n"
        #expect(throws: LUTError.malformedEntry(line: 3)) {
            try CubeLUTParser.parse(bad)
        }
    }

    @Test("Every bundled LUT parses")
    func bundledLUTsParse() throws {
        let store = LUTStore(bundle: .main)
        for name in ["Cinematic", "WarmFilm", "Airy", "Monochrome"] {
            let lut = try store.lut(named: name)
            #expect(lut.dimension == 33, "\(name) should be a 33-cube")
            #expect(lut.data.count == 33 * 33 * 33 * 4 * MemoryLayout<Float>.size)
        }
    }

    @Test("A missing LUT reports the name rather than crashing")
    func missingLUT() {
        #expect(throws: LUTError.fileNotFound("NoSuchLUT")) {
            try LUTStore(bundle: .main).lut(named: "NoSuchLUT")
        }
    }

    @Test("Repeat lookups are served from cache")
    func cachesParsedLUTs() throws {
        let store = LUTStore(bundle: .main)
        let first = try store.lut(named: "Cinematic")
        let second = try store.lut(named: "Cinematic")
        #expect(first == second)
    }
}
