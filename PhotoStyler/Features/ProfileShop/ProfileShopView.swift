import SwiftUI

struct ProfileShopView: View {
    @State private var catalog = ProfileCatalog()
    @State private var selected: StyleProfile?
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if catalog.isLoading && catalog.profiles.isEmpty {
                    ProgressView("Loading styles")
                } else if let error = catalog.loadError {
                    ContentUnavailableView(
                        "Styles Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Styles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Sort", selection: $catalog.sortOrder) {
                        ForEach(ProfileCatalog.SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .searchable(text: $catalog.searchText, prompt: "Search styles")
        }
        .task {
            await catalog.load()
            #if DEBUG
            // Screenshot/UI-test hook: jump straight to one profile's detail.
            if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-openProfile"),
               index + 1 < ProcessInfo.processInfo.arguments.count {
                let id = ProcessInfo.processInfo.arguments[index + 1]
                selected = catalog.profiles.first { $0.id == id }
            }
            #endif
        }
        .sheet(item: $selected) { profile in
            ProfileDetailView(profile: profile)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tagChips

                if catalog.filteredProfiles.isEmpty {
                    ContentUnavailableView {
                        Label("No Matching Styles", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Try removing a filter or searching for something else.")
                    } actions: {
                        Button("Clear Filters") { catalog.clearFilters() }
                    }
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(catalog.filteredProfiles) { profile in
                            Button { selected = profile } label: {
                                ProfileCard(profile: profile)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if catalog.hasActiveFilters {
                    Button {
                        catalog.clearFilters()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle.fill")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.quaternary))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(catalog.availableTags) { tag in
                    let isOn = catalog.selectedTags.contains(tag)
                    Button {
                        catalog.toggle(tag)
                    } label: {
                        Text(tag.displayName)
                            .font(.subheadline)
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(isOn ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// One card in the grid: preview, name, and the first couple of tags.
struct ProfileCard: View {
    let profile: StyleProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileThumbnail(profile: profile)
                .aspectRatio(3.0 / 4.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !profile.tags.isEmpty {
                    Text(profile.tags.prefix(2).map(\.displayName).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name). \(profile.tags.map(\.displayName).joined(separator: ", "))")
    }
}

#Preview {
    ProfileShopView()
}
