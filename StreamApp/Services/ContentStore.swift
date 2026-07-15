import Foundation
import Observation

/// Single source of truth for the content of the active playlist.
/// Loads from M3U or Xtream sources and exposes channels, movies, series and EPG.
@MainActor
@Observable
final class ContentStore {

    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var activeConfig: PlaylistConfig?
    /// True while showing built-in sample content because no playlist is configured.
    private(set) var isDemo = false
    private(set) var channels: [LiveChannel] = []
    private(set) var movies: [Movie] = []
    private(set) var series: [Series] = []
    private(set) var epg: EPGSnapshot = .empty
    private(set) var isLoadingEPG = false

    private var m3uEpisodes: [String: [Episode]] = [:]
    private var channelsByID: [String: LiveChannel] = [:]
    private var moviesByID: [String: Movie] = [:]
    private var seriesByID: [String: Series] = [:]
    private var epgTask: Task<Void, Never>?

    // MARK: - Derived Collections

    var channelGroups: [String] { orderedUniqueGroups(channels.map(\.group)) }
    var movieGroups: [String] { orderedUniqueGroups(movies.map(\.group)) }
    var seriesGroups: [String] { orderedUniqueGroups(series.map(\.group)) }

    var recentMovies: [Movie] {
        let dated = movies.filter { $0.addedAt != nil }
        if dated.isEmpty {
            return Array(movies.prefix(20))
        }
        return Array(dated.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }.prefix(20))
    }

    func channel(forKey key: String) -> LiveChannel? { channelsByID[key] }
    func movie(forKey key: String) -> Movie? { moviesByID[key] }
    func seriesItem(forKey key: String) -> Series? { seriesByID[key] }

    // MARK: - Activation

    func activateIfNeeded(_ config: PlaylistConfig?) async {
        guard let config else {
            activateDemo()
            return
        }
        if config == activeConfig, case .loaded = state { return }
        await load(config)
    }

    /// Fills the store with built-in sample content so the whole app is
    /// browsable before the user adds a playlist.
    private func activateDemo() {
        if isDemo, case .loaded = state { return }
        epgTask?.cancel()
        let demo = MockDataService.demoContent()
        activeConfig = nil
        isDemo = true
        channels = demo.channels
        movies = demo.movies
        series = demo.series
        m3uEpisodes = demo.episodesBySeriesID
        epg = demo.epg
        rebuildIndexes()
        state = .loaded
    }

    func refresh() async {
        guard let activeConfig else { return }
        await load(activeConfig)
    }

    func clear() {
        epgTask?.cancel()
        activeConfig = nil
        isDemo = false
        state = .idle
        channels = []
        movies = []
        series = []
        m3uEpisodes = [:]
        epg = .empty
        rebuildIndexes()
    }

    private func load(_ config: PlaylistConfig) async {
        epgTask?.cancel()
        activeConfig = config
        isDemo = false
        state = .loading
        do {
            switch config.kind {
            case .m3u:
                try await loadM3U(config)
            case .xtream:
                try await loadXtream(config)
            }
            rebuildIndexes()
            state = .loaded
        } catch is CancellationError {
            // A newer activation superseded this one; keep quiet.
        } catch {
            guard activeConfig == config else { return }
            state = .failed(friendlyMessage(for: error))
        }
    }

    // MARK: - M3U Loading

    private func loadM3U(_ config: PlaylistConfig) async throws {
        let (data, _) = try await URLSession.shared.data(from: config.url)
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        else { throw URLError(.cannotDecodeContentData) }

        let playlistID = config.id.uuidString
        let result = await Task.detached(priority: .userInitiated) {
            M3UParser.parse(text, playlistID: playlistID)
        }.value

        guard activeConfig == config else { throw CancellationError() }
        channels = dedupedByID(result.channels)
        movies = dedupedByID(result.movies)
        series = dedupedByID(result.series)
        m3uEpisodes = result.episodesBySeriesID

        if let epgURL = config.epgURL ?? result.epgURL {
            loadEPGInBackground(from: epgURL, for: config)
        }
    }

    // MARK: - Xtream Loading

    private func loadXtream(_ config: PlaylistConfig) async throws {
        let service = XtreamService(config: config)
        let playlistID = config.id.uuidString

        async let liveCategoriesTask = service.fetchLiveCategories()
        async let vodCategoriesTask = service.fetchVODCategories()
        async let seriesCategoriesTask = service.fetchSeriesCategories()
        async let liveTask = service.fetchLiveStreams()
        async let vodTask = service.fetchVODStreams()
        async let seriesTask = service.fetchSeries()

        let liveCategories = categoryMap(try await liveCategoriesTask)
        let vodCategories = categoryMap(try await vodCategoriesTask)
        let seriesCategories = categoryMap(try await seriesCategoriesTask)
        let liveStreams = try await liveTask
        let vodStreams = try await vodTask
        let seriesItems = try await seriesTask

        guard activeConfig == config else { throw CancellationError() }

        channels = dedupedByID(liveStreams.compactMap { stream in
            guard let streamID = stream.streamID?.value,
                  let url = service.liveStreamURL(streamID: streamID)
            else { return nil }
            return LiveChannel(
                id: "\(playlistID)|live|\(streamID)",
                number: stream.num?.intValue,
                name: stream.name ?? "Unknown",
                logoURL: nonEmptyURL(stream.streamIcon),
                streamURL: url,
                group: liveCategories[stream.categoryID?.value ?? ""] ?? "Uncategorized",
                epgChannelID: stream.epgChannelID
            )
        })

        movies = dedupedByID(vodStreams.compactMap { stream in
            guard let streamID = stream.streamID?.value,
                  let url = service.movieStreamURL(streamID: streamID, containerExtension: stream.containerExtension)
            else { return nil }
            return Movie(
                id: "\(playlistID)|movie|\(streamID)",
                title: stream.name ?? "Unknown",
                posterURL: nonEmptyURL(stream.streamIcon),
                streamURL: url,
                group: vodCategories[stream.categoryID?.value ?? ""] ?? "Uncategorized",
                year: nil,
                rating: stream.rating?.doubleValue,
                addedAt: stream.added?.doubleValue.map(Date.init(timeIntervalSince1970:)),
                vodID: streamID
            )
        })

        series = dedupedByID(seriesItems.compactMap { item in
            guard let seriesID = item.seriesID?.value else { return nil }
            return Series(
                id: "\(playlistID)|series|\(seriesID)",
                title: item.name ?? "Unknown",
                posterURL: nonEmptyURL(item.cover),
                group: seriesCategories[item.categoryID?.value ?? ""] ?? "Uncategorized",
                plot: item.plot,
                rating: item.rating?.doubleValue,
                releaseDate: item.releaseDate,
                seriesID: seriesID
            )
        })
        m3uEpisodes = [:]

        if let epgURL = service.xmltvURL {
            loadEPGInBackground(from: epgURL, for: config)
        }
    }

    // MARK: - Episodes

    /// Season number → episodes, sorted.
    func episodes(for series: Series) async throws -> [Int: [Episode]] {
        if let config = activeConfig, config.kind == .xtream, let seriesID = series.seriesID {
            let service = XtreamService(config: config)
            let info = try await service.fetchSeriesInfo(seriesID: seriesID)
            let playlistID = config.id.uuidString
            var result: [Int: [Episode]] = [:]
            for (seasonKey, episodes) in info.episodes {
                let season = Int(seasonKey) ?? 1
                result[season] = episodes.compactMap { episode in
                    guard let episodeID = episode.id?.value,
                          let url = service.episodeStreamURL(
                              episodeID: episodeID,
                              containerExtension: episode.containerExtension
                          )
                    else { return nil }
                    return Episode(
                        id: "\(playlistID)|ep|\(episodeID)",
                        title: episode.title ?? "",
                        season: episode.season?.intValue ?? season,
                        episodeNumber: episode.episodeNum?.intValue ?? 0,
                        streamURL: url,
                        plot: episode.plot,
                        durationSeconds: episode.durationSecs,
                        imageURL: nonEmptyURL(episode.movieImage)
                    )
                }
                .sorted { $0.episodeNumber < $1.episodeNumber }
            }
            return result
        }

        let episodes = m3uEpisodes[series.id] ?? []
        return Dictionary(grouping: episodes, by: \.season)
            .mapValues { $0.sorted { $0.episodeNumber < $1.episodeNumber } }
    }

    // MARK: - EPG

    func reloadEPG() {
        guard let config = activeConfig else { return }
        switch config.kind {
        case .m3u:
            if let url = config.epgURL {
                loadEPGInBackground(from: url, for: config)
            }
        case .xtream:
            if let url = XtreamService(config: config).xmltvURL {
                loadEPGInBackground(from: url, for: config)
            }
        }
    }

    private func loadEPGInBackground(from url: URL, for config: PlaylistConfig) {
        epgTask?.cancel()
        isLoadingEPG = true
        epgTask = Task { [weak self] in
            let snapshot = try? await EPGService.loadXMLTV(from: url)
            guard let self, !Task.isCancelled else { return }
            if self.activeConfig == config, let snapshot {
                self.epg = snapshot
            }
            self.isLoadingEPG = false
        }
    }

    // MARK: - Helpers

    private func rebuildIndexes() {
        channelsByID = Dictionary(channels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        moviesByID = Dictionary(movies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        seriesByID = Dictionary(series.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func categoryMap(_ categories: [XtreamCategory]) -> [String: String] {
        var map: [String: String] = [:]
        for category in categories {
            if let id = category.categoryID?.value, let name = category.categoryName {
                map[id] = name
            }
        }
        return map
    }

    private func dedupedByID<T: Identifiable>(_ items: [T]) -> [T] {
        var seen = Set<T.ID>()
        return items.filter { seen.insert($0.id).inserted }
    }

    private func orderedUniqueGroups(_ groups: [String]) -> [String] {
        var seen = Set<String>()
        return groups.filter { seen.insert($0).inserted }
    }

    private func nonEmptyURL(_ string: String?) -> URL? {
        guard let string, !string.isEmpty else { return nil }
        return URL(string: string)
    }

    private func friendlyMessage(for error: Error) -> String {
        if let xtream = error as? XtreamError {
            return xtream.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet: return "No internet connection."
            case .timedOut: return "The server took too long to respond."
            case .cannotFindHost, .cannotConnectToHost: return "Could not reach the server. Check the address."
            default: break
            }
        }
        return "Failed to load the playlist. Pull to refresh to try again."
    }
}
