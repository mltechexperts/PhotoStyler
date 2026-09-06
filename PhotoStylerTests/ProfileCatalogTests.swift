import Foundation
import Testing
@testable import PhotoStyler

@Suite("Profiles")
struct ProfileTests {

    @Test("Decodes a full profile")
    func decodesProfile() throws {
        let json = """
            {
              "id": "test", "name": "Test", "author": "ML",
              "summary": "A look.", "tags": ["warm", "film"],
              "lutName": "WarmFilm",
              "adjustments": {"fade": 0.2},
              "coverAsset": "", "sortOrder": 5
            }
            """.data(using: .utf8)!
        let p = try JSONDecoder().decode(StyleProfile.self, from: json)
        #expect(p.id == "test")
        #expect(p.tags == [.warm, .film])
        #expect(p.lutName == "WarmFilm")
        #expect(p.adjustments.fade == 0.2)
        #expect(p.sortOrder == 5)
    }

    @Test("Only id and name are required")
    func decodesMinimalProfile() throws {
        let json = #"{"id": "x", "name": "X"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(StyleProfile.self, from: json)
        #expect(p.tags.isEmpty)
        #expect(p.lutName == nil)
        #expect(p.adjustments.isNeutral)
    }

    @Test("An unknown tag still displays sensibly")
    func unknownTagDisplayName() {
        #expect(StyleTag("hand-tinted").displayName == "Hand Tinted")
        #expect(StyleTag.blackAndWhite.displayName == "Black & White")
        #expect(StyleTag.naturalSkin.displayName == "Natural Skin")
    }

    @Test("The bundled catalogue loads and leads with Original")
    func bundledCatalogueLoads() async throws {
        let profiles = try await BundledProfileRepository().loadProfiles()
        #expect(profiles.count >= 9, "8 authored profiles plus Original")
        #expect(profiles.first?.id == StyleProfile.original.id)
        #expect(profiles.first?.isOriginal == true)
    }

    @Test("Every LUT named by the catalogue exists in the bundle")
    func catalogueLUTsResolve() async throws {
        let profiles = try await BundledProfileRepository().loadProfiles()
        let store = LUTStore(bundle: .main)
        for profile in profiles {
            guard let name = profile.lutName else { continue }
            #expect(throws: Never.self, "\(profile.name) references a missing LUT") {
                try store.lut(named: name)
            }
        }
    }

    @Test("Profile ids are unique")
    func idsAreUnique() async throws {
        let profiles = try await BundledProfileRepository().loadProfiles()
        #expect(Set(profiles.map(\.id)).count == profiles.count)
    }
}
