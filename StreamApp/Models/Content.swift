import Foundation

// MARK: - Live Channel

struct LiveChannel: Identifiable, Hashable, Codable {
    let id: String
    let number: Int?
    let name: String
    let logoURL: URL?
    let streamURL: URL
    let group: String
    let epgChannelID: String?
}

// MARK: - Movie

struct Movie: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let posterURL: URL?
    let streamURL: URL
    let group: String
    let year: String?
    let rating: Double?
    let addedAt: Date?
    /// Xtream VOD id, used to fetch extended details on demand.
    let vodID: String?
    var plot: String?
    var genre: String?
    var cast: String?
    var durationText: String?
    /// Direct-playable trailer stream, when available.
    var trailerURL: URL?
}

// MARK: - Series

struct Series: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let posterURL: URL?
    let group: String
    let plot: String?
    let rating: Double?
    let releaseDate: String?
    /// Xtream series id, used to fetch episodes on demand.
    let seriesID: String?
}

struct Episode: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let season: Int
    let episodeNumber: Int
    let streamURL: URL
    let plot: String?
    let durationSeconds: Int?
    let imageURL: URL?
}

// MARK: - Playable Item

/// A fully resolved item the player can start immediately, regardless of source.
struct PlayableItem: Identifiable, Hashable {
    enum Kind: String {
        case live, movie, episode
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let url: URL
    let epgChannelID: String?
}

extension LiveChannel {
    var playable: PlayableItem {
        PlayableItem(
            id: id,
            kind: .live,
            title: name,
            subtitle: group,
            artworkURL: logoURL,
            url: streamURL,
            epgChannelID: epgChannelID
        )
    }
}

extension Movie {
    var playable: PlayableItem {
        PlayableItem(
            id: id,
            kind: .movie,
            title: title,
            subtitle: year,
            artworkURL: posterURL,
            url: streamURL,
            epgChannelID: nil
        )
    }

    var hasTrailer: Bool { trailerURL != nil }

    /// A playable item for the trailer (kept distinct so it never overwrites
    /// the movie's own watch progress).
    var trailerPlayable: PlayableItem? {
        guard let trailerURL else { return nil }
        return PlayableItem(
            id: "\(id)|trailer",
            kind: .movie,
            title: "\(title) — Trailer",
            subtitle: year,
            artworkURL: posterURL,
            url: trailerURL,
            epgChannelID: nil
        )
    }
}

extension Episode {
    func playable(in series: Series) -> PlayableItem {
        PlayableItem(
            id: id,
            kind: .episode,
            title: title.isEmpty ? "Episode \(episodeNumber)" : title,
            subtitle: "\(series.title) · S\(season) E\(episodeNumber)",
            artworkURL: imageURL ?? series.posterURL,
            url: streamURL,
            epgChannelID: nil
        )
    }
}
