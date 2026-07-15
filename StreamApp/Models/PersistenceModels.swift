import Foundation
import SwiftData

enum PlaylistKind: String, CaseIterable, Identifiable {
    case m3u
    case xtream

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .m3u: "M3U Playlist"
        case .xtream: "Xtream Codes"
        }
    }
}

enum ContentKind: String {
    case live, movie, series
}

// MARK: - SwiftData Entities

@Model
final class PlaylistEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var urlString: String
    var username: String
    var password: String
    var epgURLString: String?
    var isActive: Bool
    var createdAt: Date

    init(
        name: String,
        kind: PlaylistKind,
        urlString: String,
        username: String = "",
        password: String = "",
        epgURLString: String? = nil,
        isActive: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.urlString = urlString
        self.username = username
        self.password = password
        self.epgURLString = epgURLString
        self.isActive = isActive
        self.createdAt = .now
    }

    var kind: PlaylistKind { PlaylistKind(rawValue: kindRaw) ?? .m3u }
}

@Model
final class FavoriteEntity {
    @Attribute(.unique) var key: String
    var kindRaw: String
    var addedAt: Date

    init(key: String, kind: ContentKind) {
        self.key = key
        self.kindRaw = kind.rawValue
        self.addedAt = .now
    }
}

@Model
final class WatchProgressEntity {
    @Attribute(.unique) var key: String
    var kindRaw: String
    var title: String
    var subtitle: String?
    var artworkURLString: String?
    var streamURLString: String
    var position: Double
    var duration: Double
    var updatedAt: Date

    init(
        key: String,
        kind: PlayableItem.Kind,
        title: String,
        subtitle: String?,
        artworkURLString: String?,
        streamURLString: String,
        position: Double,
        duration: Double
    ) {
        self.key = key
        self.kindRaw = kind.rawValue
        self.title = title
        self.subtitle = subtitle
        self.artworkURLString = artworkURLString
        self.streamURLString = streamURLString
        self.position = position
        self.duration = duration
        self.updatedAt = .now
    }

    var fractionWatched: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, position / duration))
    }

    var playable: PlayableItem? {
        guard let url = URL(string: streamURLString) else { return nil }
        return PlayableItem(
            id: key,
            kind: PlayableItem.Kind(rawValue: kindRaw) ?? .movie,
            title: title,
            subtitle: subtitle,
            artworkURL: artworkURLString.flatMap(URL.init(string:)),
            url: url,
            epgChannelID: nil
        )
    }
}

// MARK: - Value Config

/// Thread-safe value copy of a `PlaylistEntity`, safe to hand to services.
struct PlaylistConfig: Hashable {
    let id: UUID
    let name: String
    let kind: PlaylistKind
    let url: URL
    let username: String
    let password: String
    let epgURL: URL?

    init?(entity: PlaylistEntity) {
        guard let url = URL(string: entity.urlString) else { return nil }
        self.id = entity.id
        self.name = entity.name
        self.kind = entity.kind
        self.url = url
        self.username = entity.username
        self.password = entity.password
        self.epgURL = entity.epgURLString.flatMap(URL.init(string:))
    }
}
