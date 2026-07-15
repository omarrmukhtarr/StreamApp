import Foundation
import SwiftData
import SwiftUI

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

// MARK: - Playlist

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

// MARK: - Profile

@Model
final class ProfileEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbol: String
    /// Index into `ProfileEntity.palette`, so the avatar has a stable color.
    var colorIndex: Int
    var isKids: Bool
    var createdAt: Date

    init(name: String, symbol: String = "person.fill", colorIndex: Int = 0, isKids: Bool = false) {
        self.id = UUID()
        self.name = name
        self.symbol = symbol
        self.colorIndex = colorIndex
        self.isKids = isKids
        self.createdAt = .now
    }

    /// Fixed palette so a profile's color is derived from its stored index.
    static let palette: [Color] = [.indigo, .cyan, .pink, .orange, .green, .purple, .teal, .red]

    var color: Color { Self.palette[colorIndex % Self.palette.count] }
}

// MARK: - Favorites (profile-scoped)

@Model
final class FavoriteEntity {
    /// Composite unique key: "<profileID>|<contentKey>".
    @Attribute(.unique) var id: String
    var contentKey: String
    var profileID: UUID
    var kindRaw: String
    var addedAt: Date

    init(contentKey: String, kind: ContentKind, profileID: UUID) {
        self.id = "\(profileID.uuidString)|\(contentKey)"
        self.contentKey = contentKey
        self.profileID = profileID
        self.kindRaw = kind.rawValue
        self.addedAt = .now
    }
}

// MARK: - Watch Progress (profile-scoped)

@Model
final class WatchProgressEntity {
    /// Composite unique key: "<profileID>|<contentKey>".
    @Attribute(.unique) var id: String
    var contentKey: String
    var profileID: UUID
    var kindRaw: String
    var title: String
    var subtitle: String?
    var artworkURLString: String?
    var streamURLString: String
    var position: Double
    var duration: Double
    var updatedAt: Date

    init(
        contentKey: String,
        profileID: UUID,
        kind: PlayableItem.Kind,
        title: String,
        subtitle: String?,
        artworkURLString: String?,
        streamURLString: String,
        position: Double,
        duration: Double
    ) {
        self.id = "\(profileID.uuidString)|\(contentKey)"
        self.contentKey = contentKey
        self.profileID = profileID
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
            id: contentKey,
            kind: PlayableItem.Kind(rawValue: kindRaw) ?? .movie,
            title: title,
            subtitle: subtitle,
            artworkURL: artworkURLString.flatMap(URL.init(string:)),
            url: url,
            epgChannelID: nil
        )
    }
}

// MARK: - Downloads (profile-scoped)

enum DownloadState: String, Codable {
    case downloading, completed, failed
}

@Model
final class DownloadEntity {
    /// Composite unique key: "<profileID>|<contentKey>".
    @Attribute(.unique) var id: String
    var contentKey: String
    var profileID: UUID
    var title: String
    var subtitle: String?
    var artworkURLString: String?
    var remoteURLString: String
    /// File name inside the app's Downloads directory (once completed).
    var localFileName: String?
    var stateRaw: String
    var progress: Double
    var createdAt: Date

    init(
        contentKey: String,
        profileID: UUID,
        title: String,
        subtitle: String?,
        artworkURLString: String?,
        remoteURLString: String
    ) {
        self.id = "\(profileID.uuidString)|\(contentKey)"
        self.contentKey = contentKey
        self.profileID = profileID
        self.title = title
        self.subtitle = subtitle
        self.artworkURLString = artworkURLString
        self.remoteURLString = remoteURLString
        self.localFileName = nil
        self.stateRaw = DownloadState.downloading.rawValue
        self.progress = 0
        self.createdAt = .now
    }

    var state: DownloadState {
        get { DownloadState(rawValue: stateRaw) ?? .downloading }
        set { stateRaw = newValue.rawValue }
    }

    /// Absolute URL of the finished file on disk, if present.
    var localURL: URL? {
        guard let localFileName else { return nil }
        return DownloadManager.downloadsDirectory.appendingPathComponent(localFileName)
    }

    /// A playable item that streams from the local file when complete.
    var playable: PlayableItem? {
        guard state == .completed, let localURL else { return nil }
        return PlayableItem(
            id: contentKey,
            kind: .movie,
            title: title,
            subtitle: subtitle,
            artworkURL: artworkURLString.flatMap(URL.init(string:)),
            url: localURL,
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
