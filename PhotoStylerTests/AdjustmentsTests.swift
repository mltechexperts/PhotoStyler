import Foundation
import Testing
@testable import PhotoStyler

@Suite("Adjustments")
struct AdjustmentsTests {

    @Test("Neutral is the identity")
    func neutralIsIdentity() {
        #expect(Adjustments.neutral.isNeutral)
        #expect(Adjustments().exposure == 0)
        #expect(Adjustments().contrast == 1)
        #expect(Adjustments().saturation == 1)
    }

    @Test("Decoding fills in every unspecified parameter")
    func decodesPartialJSON() throws {
        let json = #"{"exposure": 0.5, "grain": 0.25}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(Adjustments.self, from: json)
        #expect(a.exposure == 0.5)
        #expect(a.grain == 0.25)
        // Unmentioned parameters must land on their neutral values, not zero.
        #expect(a.contrast == 1)
        #expect(a.saturation == 1)
        #expect(a.vignette == 0)
    }

    @Test("Decoding an empty object yields neutral")
    func decodesEmpty() throws {
        let a = try JSONDecoder().decode(Adjustments.self, from: Data("{}".utf8))
        #expect(a.isNeutral)
    }

    @Test("Out-of-range values are clamped")
    func clampsExtremes() {
        var a = Adjustments()
        a.exposure = 99
        a.contrast = -5
        a.saturation = 42
        a.temperature = -8
        a.grain = 3
        a.vignette = -1

        let c = a.clamped()
        #expect(c.exposure == 2)
        #expect(c.contrast == 0)
        #expect(c.saturation == 2)
        #expect(c.temperature == -1)
        #expect(c.grain == 1)
        #expect(c.vignette == 0)
    }

    @Test("Clamping leaves in-range values alone")
    func clampIsIdentityInRange() {
        let a = Adjustments(exposure: 0.4, contrast: 1.1, saturation: 0.9)
        #expect(a.clamped() == a)
    }
}
