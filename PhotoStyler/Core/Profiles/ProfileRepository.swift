import Foundation
import OSLog

/// Source of the profile catalogue.
///
/// The app talks only to this protocol, so the current bundled catalogue can be
/// replaced by a downloading, purchase-aware implementation (D4) without any
/// change to the shop or camera UI.
nonisolated protocol ProfileRepository: Sendable {
    func loadProfiles() async throws -> [StyleProfile]
}

/// Reads `profiles.json` from the app bundle.
nonisolated struct BundledProfileRepository: ProfileRepository {
    private static let logger = Logger(subsystem: "com.mlcreativestudios.PhotoStyler", category: "profiles")

    let bundle: Bundle
    let manifestName: String

    init(bundle: Bundle = .main, manifestName: String = "profiles") {
        self.bundle = bundle
        self.manifestName = manifestName
    }

    func loadProfiles() async throws -> [StyleProfile] {
        guard let url = bundle.url(forResource: manifestName, withExtension: "json") else {
            Self.logger.error("profiles.json missing from bundle")
            return [.original]
        }
        let decoded = try JSONDecoder().decode([StyleProfile].self, from: Data(contentsOf: url))
        // "Original" is synthesised rather than authored so it can never be
        // renamed or removed by a manifest edit.
        return [.original] + decoded.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
    }
}
