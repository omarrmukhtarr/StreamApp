import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(ContentStore.self) private var store
    @Environment(PlaybackCoordinator.self) private var playback
    @Query(sort: \WatchProgressEntity.updatedAt, order: .reverse)
    private var watchProgress: [WatchProgressEntity]
    @Query(sort: \FavoriteEntity.addedAt, order: .reverse)
    private var favorites: [FavoriteEntity]

    @State private var showAddPlaylist = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            content
                .appBackground()
                .navigationTitle("StreamApp")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showAddPlaylist) {
                AddPlaylistView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
            ErrorStateView(message: message) {
                await store.refresh()
            }
        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if store.isDemo {
                        demoBanner
                    }

                    statsHeader

                    if !continueWatching.isEmpty {
                        continueWatchingSection
                    }
                    if !favoriteChannels.isEmpty || !favoriteMovies.isEmpty || !favoriteSeries.isEmpty {
                        favoritesSection
                    }
                    if !store.channels.isEmpty {
                        liveChannelsSection
                    }
                    if !store.recentMovies.isEmpty {
                        recentMoviesSection
                    }
                    if !store.series.isEmpty {
                        seriesSection
                    }
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

    // MARK: - Sections

    private var continueWatching: [WatchProgressEntity] {
        Array(watchProgress.prefix(15))
    }

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Continue Watching", systemImage: "play.circle")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
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
                .padding(.horizontal)
            }
        }
    }

    private var favoriteChannels: [LiveChannel] {
        favorites.compactMap { store.channel(forKey: $0.key) }
    }

    private var favoriteMovies: [Movie] {
        favorites.compactMap { store.movie(forKey: $0.key) }
    }

    private var favoriteSeries: [Series] {
        favorites.compactMap { store.seriesItem(forKey: $0.key) }
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Favorites", systemImage: "star")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(favoriteChannels) { channel in
                        Button {
                            playback.play(channel.playable)
                        } label: {
                            favoriteChannelCard(channel)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(favoriteMovies) { movie in
                        NavigationLink {
                            MovieDetailView(movie: movie)
                        } label: {
                            PosterCard(title: movie.title, imageURL: movie.posterURL, width: 110)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(favoriteSeries) { series in
                        NavigationLink {
                            SeriesDetailView(series: series)
                        } label: {
                            PosterCard(title: series.title, imageURL: series.posterURL, width: 110)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func favoriteChannelCard(_ channel: LiveChannel) -> some View {
        VStack(spacing: 8) {
            RemoteImage(url: channel.logoURL, systemFallback: "tv", contentMode: .fit)
                .frame(width: 64, height: 64)
                .padding(10)
                .glassEffect(.regular, in: .circle)
            Text(channel.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: 84)
        }
    }

    private var liveChannelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Live Now", systemImage: "dot.radiowaves.left.and.right")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(store.channels.prefix(15)) { channel in
                        Button {
                            playback.play(channel.playable)
                        } label: {
                            favoriteChannelCard(channel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var recentMoviesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recently Added Movies", systemImage: "sparkles")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(store.recentMovies) { movie in
                        NavigationLink {
                            MovieDetailView(movie: movie)
                        } label: {
                            PosterCard(
                                title: movie.title,
                                imageURL: movie.posterURL,
                                subtitle: movie.group,
                                width: 120
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var seriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Series", systemImage: "rectangle.stack.badge.play")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(store.series.prefix(20)) { series in
                        NavigationLink {
                            SeriesDetailView(series: series)
                        } label: {
                            PosterCard(
                                title: series.title,
                                imageURL: series.posterURL,
                                subtitle: series.group,
                                width: 120
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
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
