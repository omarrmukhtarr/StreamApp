import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(ContentStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PlaylistEntity.createdAt) private var playlists: [PlaylistEntity]
    @Query private var favorites: [FavoriteEntity]
    @Query private var watchProgress: [WatchProgressEntity]

    @State private var showAddPlaylist = false
    @State private var confirmClearHistory = false
    @State private var confirmClearFavorites = false

    var body: some View {
        NavigationStack {
            List {
                playlistsSection
                epgSection
                librarySection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddPlaylist) {
                AddPlaylistView()
            }
        }
    }

    // MARK: - Playlists

    private var playlistsSection: some View {
        Section("Playlists") {
            ForEach(playlists) { playlist in
                Button {
                    setActive(playlist)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: playlist.kind == .xtream ? "server.rack" : "list.bullet.rectangle")
                            .foregroundStyle(LinearGradient.brand)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(playlist.kind.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if playlist.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deletePlaylists)

            Button {
                showAddPlaylist = true
            } label: {
                Label("Add Playlist", systemImage: "plus")
            }
        }
    }

    // MARK: - EPG

    private var epgSection: some View {
        Section("TV Guide (EPG)") {
            HStack {
                Label("Programs Loaded", systemImage: "calendar")
                Spacer()
                if store.isLoadingEPG {
                    ProgressView()
                } else {
                    Text("\(store.epg.programCount)")
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                store.reloadEPG()
            } label: {
                Label("Refresh Guide", systemImage: "arrow.clockwise")
            }
            .disabled(store.isLoadingEPG || store.activeConfig == nil)
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        Section("Library") {
            Button(role: .destructive) {
                confirmClearHistory = true
            } label: {
                Label("Clear Watch History (\(watchProgress.count))", systemImage: "trash")
            }
            .confirmationDialog("Clear all watch history?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    watchProgress.forEach(modelContext.delete)
                    try? modelContext.save()
                }
            }

            Button(role: .destructive) {
                confirmClearFavorites = true
            } label: {
                Label("Clear Favorites (\(favorites.count))", systemImage: "star.slash")
            }
            .confirmationDialog("Remove all favorites?", isPresented: $confirmClearFavorites, titleVisibility: .visible) {
                Button("Clear Favorites", role: .destructive) {
                    favorites.forEach(modelContext.delete)
                    try? modelContext.save()
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            Label("Built with SwiftUI & Liquid Glass", systemImage: "sparkles")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func setActive(_ playlist: PlaylistEntity) {
        for item in playlists {
            item.isActive = (item.id == playlist.id)
        }
        try? modelContext.save()
    }

    private func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(playlists[index])
        }
        // Keep exactly one active playlist if any remain.
        let remaining = playlists.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        if !remaining.isEmpty, !remaining.contains(where: \.isActive) {
            remaining.first?.isActive = true
        }
        try? modelContext.save()
    }
}
