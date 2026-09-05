import Observation
import OSLog

/// Backing state for the shop: the catalogue plus the current search and filter.
@MainActor
@Observable
final class ProfileCatalog {

    private static let logger = Logger(
        subsystem: "com.mlcreativestudios.PhotoStyler", category: "catalog"
    )

    enum SortOrder: String, CaseIterable, Identifiable {
        case curated = "Curated"
        case name = "Name"
        var id: String { rawValue }
    }

    private(set) var profiles: [StyleProfile] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    var searchText = ""
    var selectedTags: Set<StyleTag> = []
    var sortOrder: SortOrder = .curated

    private let repository: any ProfileRepository

    init(repository: any ProfileRepository = BundledProfileRepository()) {
        self.repository = repository
    }

    func load() async {
        guard profiles.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            profiles = try await repository.loadProfiles()
        } catch {
            loadError = error.localizedDescription
            Self.logger.error("Catalogue load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Tags that actually appear in the catalogue, in curated order, so the chip
    /// row never offers a filter that would return nothing.
    var availableTags: [StyleTag] {
        let present = Set(profiles.flatMap(\.tags))
        let curated = StyleTag.curated.filter(present.contains)
        let extras = present.subtracting(curated).sorted { $0.rawValue < $1.rawValue }
        return curated + extras
    }

    var filteredProfiles: [StyleProfile] {
        var result = profiles.filter { !$0.isOriginal }

        if !selectedTags.isEmpty {
            // AND across tags: each additional chip narrows the result.
            result = result.filter { selectedTags.isSubset(of: Set($0.tags)) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            result = result.filter { profile in
                profile.name.localizedCaseInsensitiveContains(query)
                    || profile.summary.localizedCaseInsensitiveContains(query)
                    || profile.tags.contains { $0.displayName.localizedCaseInsensitiveContains(query) }
            }
        }

        switch sortOrder {
        case .curated:
            return result.sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
        case .name:
            return result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }

    func toggle(_ tag: StyleTag) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    func clearFilters() {
        selectedTags.removeAll()
        searchText = ""
    }

    var hasActiveFilters: Bool {
        !selectedTags.isEmpty || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
