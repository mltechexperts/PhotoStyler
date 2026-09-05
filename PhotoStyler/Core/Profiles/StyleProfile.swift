import Foundation

/// A browsable category label. Backed by a raw string so the profile manifest
/// can introduce new tags without an app update.
nonisolated struct StyleTag: RawRepresentable, Codable, Sendable, Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }

    static let cinematic     = StyleTag("cinematic")
    static let editorial     = StyleTag("editorial")
    static let film          = StyleTag("film")
    static let warm          = StyleTag("warm")
    static let cool          = StyleTag("cool")
    static let moody         = StyleTag("moody")
    static let airy          = StyleTag("airy")
    static let vintage       = StyleTag("vintage")
    static let bold          = StyleTag("bold")
    static let clean         = StyleTag("clean")
    static let naturalSkin   = StyleTag("natural-skin")
    static let wedding       = StyleTag("wedding")
    static let portrait      = StyleTag("portrait")
    static let blackAndWhite = StyleTag("black-and-white")

    /// Order used for the filter chips in the shop.
    static let curated: [StyleTag] = [
        .cinematic, .editorial, .film, .warm, .cool, .moody, .airy,
        .vintage, .bold, .clean, .naturalSkin, .wedding, .portrait, .blackAndWhite,
    ]

    /// Human-readable name. Falls back to a title-cased raw value so an
    /// unrecognised tag from the manifest still displays sensibly.
    var displayName: String {
        switch self {
        case .naturalSkin: "Natural Skin"
        case .blackAndWhite: "Black & White"
        default:
            rawValue
                .split(separator: "-")
                .map(\.capitalized)
                .joined(separator: " ")
        }
    }
}

/// A named look: a LUT for colour grading plus adjustments layered on top.
nonisolated struct StyleProfile: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let name: String
    let author: String
    let summary: String
    let tags: [StyleTag]
    /// Basename of a `.cube` file in the bundle. `nil` means the profile is
    /// expressed purely through `adjustments`.
    let lutName: String?
    let adjustments: Adjustments
    /// Asset-catalogue name of the cover image shown in the shop grid.
    let coverAsset: String
    let sortOrder: Int

    init(
        id: String,
        name: String,
        author: String,
        summary: String = "",
        tags: [StyleTag] = [],
        lutName: String? = nil,
        adjustments: Adjustments = .neutral,
        coverAsset: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.summary = summary
        self.tags = tags
        self.lutName = lutName
        self.adjustments = adjustments
        self.coverAsset = coverAsset
        self.sortOrder = sortOrder
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        name        = try c.decode(String.self, forKey: .name)
        author      = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        summary     = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        tags        = try c.decodeIfPresent([StyleTag].self, forKey: .tags) ?? []
        lutName     = try c.decodeIfPresent(String.self, forKey: .lutName)
        adjustments = try c.decodeIfPresent(Adjustments.self, forKey: .adjustments) ?? .neutral
        coverAsset  = try c.decodeIfPresent(String.self, forKey: .coverAsset) ?? ""
        sortOrder   = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    /// The unedited pass-through shown first in the picker.
    static let original = StyleProfile(
        id: "original",
        name: "Original",
        author: "",
        summary: "No styling applied.",
        sortOrder: -1
    )

    var isOriginal: Bool { id == StyleProfile.original.id }
}
