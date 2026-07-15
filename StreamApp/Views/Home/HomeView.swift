import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(ContentStore.self) private var store
    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(ProfileStore.self) private var profiles
    @Query(sort: \WatchProgressEntity.updatedAt, order: .reverse)
    private var watchProgress: [WatchProgressEntity]
    @Query(sort: \FavoriteEntity.addedAt, order: .reverse)
    private var favorites: [FavoriteEntity]
    @Query(sort: \DownloadEntity.createdAt, order: .reverse)
    private var downloads: [DownloadEntity]
    @Query private var allProfiles: [ProfileEntity]

    @State private var showAddPlaylist = false
    @State private var showSettings = false
    @State private var showProfiles = false
    @State private var showDownloads = false

    private var currentProfile: ProfileEntity? {
        allProfiles.first { $0.id == profiles.currentID }
    }

    var body: some View {
        NavigationStack {
            content
                .appBackground()
                .navigationTitle("StreamApp")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showAddPlaylist) { AddPlaylistView() }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .sheet(isPresented: $showProfiles) { ProfilesView() }
                .sheet(isPresented: $showDownloads) { DownloadsView() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if let currentProfile {
                Button { showProfiles = true } label: {
                    ProfileAvatar(profile: currentProfile, size: 30)
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { showDownloads = true } label: {
                Image(systemName: "arrow.down.circle")
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            LoadingStateView(message: "Loading your content…")
        case .failed(let message):
            ErrorStateView(message: message) { await store.refresh() }
        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if store.isDemo { demoBanner }

                    statsHeader

                    if !continueWatching.isEmpty { continueWatchingSection }
                    if !completedDownloads.isEmpty { downloadsSection }
                    if hasFavorites { favoritesSection }
                    if !trailerMovies.isEmpty { trailersSection }
                    if !store.channels.isEmpty { liveChannelsSection }
                    if !store.recentMovies.isEmpty { recentMoviesSection }
                    if !store.series.isEmpty { seriesSection }
                }
                .padding(.vertical)
            }
            .refreshable { await store.refresh() }
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCard(count: store.channels.count, label: "Channels", icon: "tv")
            statCard(count: store.movies.count, label: "Movies", icon: "film")
            statCard(count: store.series.count, label: "Series", icon: "rectangle.stack")
        }
        .padding(.horizontal)
    }

    private func statCard(count: Int, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(LinearGradient.brand)
            Text("\(count)")
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Profile-scoped data

    private var continueWatching: [WatchProgressEntity] {
        watchProgress.filter { $0.profileID == profiles.currentID }.prefix(15).map { $0 }
    }

    private var completedDownloads: [DownloadEntity] {
        downloads.filter { $0.profileID == profiles.currentID && $0.state == .completed }
    }

    private var scopedFavorites: [FavoriteEntity] {
        favorites.filter { $0.profileID == profiles.currentID }
    }

    private var favoriteChannels: [LiveChannel] { scopedFavorites.compactMap { store.channel(forKey: $0.contentKey) } }
    private var favoriteMovies: [Movie] { scopedFavorites.compactMap { store.movie(forKey: $0.contentKey) } }
    private var favoriteSeries: [Series] { scopedFavorites.compactMap { store.seriesItem(forKey: $0.contentKey) } }
    private var hasFavorites: Bool { !favoriteChannels.isEmpty || !favoriteMovies.isEmpty || !favoriteSeries.isEmpty }

    private var trailerMovies: [Movie] { Array(store.movies.filter(\.hasTrailer).prefix(15)) }

    // MARK: - Sections

    private var continueWatchingSection: some View {
        HScrollSection(title: "Continue Watching", systemImage: "play.circle") {
            ForEach(continueWatching) { progress in
                if let playable = progress.playable {
                    Button {
                        playback.play(playable)
                    } label: {
                        PosterCard(
                            title: progress.title,
                            imageURL: progress.artworkURLString.flatMap(URL.init(string:)),
                            subtitle: progress.subtitle,
                            progress: progress.fractionWatched,
                            width: 130
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var downloadsSection: some View {
        HScrollSection(title: "Downloaded", systemImage: "arrow.down.circle") {
            ForEach(completedDownloads) { download in
                if let playable = download.playable {
                    Button {
                        playback.play(playable)
                    } label: {
                        PosterCard(
                            title: download.title,
                            imageURL: download.artworkURLString.flatMap(URL.init(string:)),
                            subtitle: "Offline",
                            width: 120
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var favoritesSection: some View {
        HScrollSection(title: "Favorites", systemImage: "star") {
            ForEach(favoriteChannels) { channel in
                Button { playback.play(channel.playable) } label: {
                    ChannelAvatarCard(channel: channel)
                }
                .buttonStyle(.plain)
            }
            ForEach(favoriteMovies) { movie in
                MovieCard(movie: movie, width: 110, showSubtitle: false)
            }
            ForEach(favoriteSeries) { series in
                SeriesCard(series: series, width: 110, showSubtitle: false)
            }
        }
    }

    private var trailersSection: some View {
        HScrollSection(title: "Trailers", systemImage: "movieclapper") {
            ForEach(trailerMovies) { movie in
                if let trailer = movie.trailerPlayable {
                    Button {
                        playback.play(trailer)
                    } label: {
                        PosterCard(
                            title: movie.title,
                            imageURL: movie.posterURL,
                            subtitle: "▶ Trailer",
                            width: 150
                        )
                        .frame(width: 150)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var liveChannelsSection: some View {
        HScrollSection(title: "Live Now", systemImage: "dot.radiowaves.left.and.right") {
            ForEach(store.channels.prefix(15)) { channel in
                Button { playback.play(channel.playable) } label: {
                    ChannelAvatarCard(channel: channel)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentMoviesSection: some View {
        HScrollSection(title: "Recently Added Movies", systemImage: "sparkles") {
            ForEach(store.recentMovies) { movie in
                MovieCard(movie: movie, width: 120)
            }
        }
    }

    private var seriesSection: some View {
        HScrollSection(title: "Series", systemImage: "rectangle.stack.badge.play") {
            ForEach(store.series.prefix(20)) { series in
                SeriesCard(series: series, width: 120)
            }
        }
    }

    // MARK: - Demo Banner

    private var demoBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.tv")
                    .font(.title3)
                    .foregroundStyle(LinearGradient.brand)
                Text("Demo Mode")
                    .font(.headline)
                Spacer()
            }

            Text("You're browsing sample content. Add your own M3U playlist or Xtream Codes account to start streaming your channels.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showAddPlaylist = true
            } label: {
                Label("Add Playlist", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(.brandPrimary)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }
}
