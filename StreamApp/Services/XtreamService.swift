import Foundation

enum XtreamError: LocalizedError {
    case invalidURL
    case authenticationFailed
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The server address is not a valid URL."
        case .authenticationFailed: "Login failed. Check the server, username and password."
        case .badResponse: "The server returned an unexpected response."
        }
    }
}

/// Client for the Xtream Codes `player_api.php` API.
struct XtreamService {
    let baseURL: URL
    let username: String
    let password: String

    init(config: PlaylistConfig) {
        self.baseURL = config.url
        self.username = config.username
        self.password = config.password
    }

    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
    }

    // MARK: - Endpoints

    func authenticate() async throws {
        let data = try await fetch(action: nil)
        let response = try JSONDecoder().decode(XtreamAuthResponse.self, from: data)
        guard response.userInfo?.isAuthenticated == true else {
            throw XtreamError.authenticationFailed
        }
    }

    func fetchLiveCategories() async throws -> [XtreamCategory] {
        try await fetchList(action: "get_live_categories")
    }

    func fetchVODCategories() async throws -> [XtreamCategory] {
        try await fetchList(action: "get_vod_categories")
    }

    func fetchSeriesCategories() async throws -> [XtreamCategory] {
        try await fetchList(action: "get_series_categories")
    }

    func fetchLiveStreams() async throws -> [XtreamLiveStream] {
        try await fetchList(action: "get_live_streams")
    }

    func fetchVODStreams() async throws -> [XtreamVODStream] {
        try await fetchList(action: "get_vod_streams")
    }

    func fetchSeries() async throws -> [XtreamSeriesItem] {
        try await fetchList(action: "get_series")
    }

    func fetchSeriesInfo(seriesID: String) async throws -> XtreamSeriesInfo {
        let data = try await fetch(action: "get_series_info", extra: ["series_id": seriesID])
        return try JSONDecoder().decode(XtreamSeriesInfo.self, from: data)
    }

    func fetchVODInfo(vodID: String) async throws -> XtreamVODInfo {
        let data = try await fetch(action: "get_vod_info", extra: ["vod_id": vodID])
        return try JSONDecoder().decode(XtreamVODInfo.self, from: data)
    }

    func fetchShortEPG(streamID: String, limit: Int = 10) async throws -> [EPGProgram] {
        let data = try await fetch(action: "get_short_epg", extra: ["stream_id": streamID, "limit": String(limit)])
        let response = try JSONDecoder().decode(XtreamEPGResponse.self, from: data)
        return (response.epgListings ?? []).compactMap { $0.program(channelID: streamID) }
    }

    // MARK: - Stream URLs

    func liveStreamURL(streamID: String) -> URL? {
        streamURL(path: "live", id: streamID, ext: "m3u8")
    }

    func movieStreamURL(streamID: String, containerExtension: String?) -> URL? {
        streamURL(path: "movie", id: streamID, ext: containerExtension ?? "mp4")
    }

    func episodeStreamURL(episodeID: String, containerExtension: String?) -> URL? {
        streamURL(path: "series", id: episodeID, ext: containerExtension ?? "mp4")
    }

    var xmltvURL: URL? {
        var components = URLComponents(url: baseURL.appending(path: "xmltv.php"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        return components?.url
    }

    private func streamURL(path: String, id: String, ext: String) -> URL? {
        guard !id.isEmpty else { return nil }
        let cleanExt = ext.isEmpty ? "mp4" : ext
        return baseURL
            .appending(path: path)
            .appending(path: username)
            .appending(path: password)
            .appending(path: "\(id).\(cleanExt)")
    }

    // MARK: - Networking

    private func fetchList<T: Decodable>(action: String) async throws -> [T] {
        let data = try await fetch(action: action)
        // Some panels return `{}` instead of `[]` for empty lists.
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }

    private func fetch(action: String?, extra: [String: String] = [:]) async throws -> Data {
        guard var components = URLComponents(
            url: baseURL.appending(path: "player_api.php"),
            resolvingAgainstBaseURL: false
        ) as URLComponents? else { throw XtreamError.invalidURL }

        var items = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        if let action {
            items.append(URLQueryItem(name: "action", value: action))
        }
        for (key, value) in extra {
            items.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = items

        guard let url = components.url else { throw XtreamError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw http.statusCode == 401 ? XtreamError.authenticationFailed : XtreamError.badResponse
        }
        return data
    }
}

// MARK: - Flexible JSON Value

/// Xtream panels are inconsistent about types (numbers as strings, etc.);
/// this decodes any scalar into a string.
struct FlexString: Decodable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let double = try? container.decode(Double.self) {
            value = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            value = String(bool)
        } else {
            value = ""
        }
    }

    var intValue: Int? { Int(value) ?? Int(Double(value) ?? .nan) }
    var doubleValue: Double? { Double(value) }
}

// MARK: - DTOs

struct XtreamAuthResponse: Decodable {
    let userInfo: UserInfo?

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
    }

    struct UserInfo: Decodable {
        let auth: FlexString?
        let status: String?

        var isAuthenticated: Bool {
            if let auth, auth.value == "1" || auth.value == "true" { return true }
            return status?.lowercased() == "active"
        }
    }
}

struct XtreamCategory: Decodable {
    let categoryID: FlexString?
    let categoryName: String?

    enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
    }
}

struct XtreamLiveStream: Decodable {
    let num: FlexString?
    let name: String?
    let streamID: FlexString?
    let streamIcon: String?
    let epgChannelID: String?
    let categoryID: FlexString?

    enum CodingKeys: String, CodingKey {
        case num, name
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelID = "epg_channel_id"
        case categoryID = "category_id"
    }
}

struct XtreamVODStream: Decodable {
    let name: String?
    let streamID: FlexString?
    let streamIcon: String?
    let categoryID: FlexString?
    let rating: FlexString?
    let containerExtension: String?
    let added: FlexString?

    enum CodingKeys: String, CodingKey {
        case name, rating, added
        case streamID = "stream_id"
        case streamIcon = "stream_icon"
        case categoryID = "category_id"
        case containerExtension = "container_extension"
    }
}

struct XtreamSeriesItem: Decodable {
    let name: String?
    let seriesID: FlexString?
    let cover: String?
    let plot: String?
    let categoryID: FlexString?
    let rating: FlexString?
    let releaseDate: String?

    enum CodingKeys: String, CodingKey {
        case name, cover, plot, rating
        case seriesID = "series_id"
        case categoryID = "category_id"
        case releaseDate = "releaseDate"
    }
}

struct XtreamEpisode: Decodable {
    let id: FlexString?
    let title: String?
    let containerExtension: String?
    let season: FlexString?
    let episodeNum: FlexString?
    let plot: String?
    let durationSecs: Int?
    let movieImage: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, season, info
        case containerExtension = "container_extension"
        case episodeNum = "episode_num"
    }

    private enum InfoKeys: String, CodingKey {
        case plot
        case durationSecs = "duration_secs"
        case movieImage = "movie_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(FlexString.self, forKey: .id)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        containerExtension = try? container.decodeIfPresent(String.self, forKey: .containerExtension)
        season = try? container.decodeIfPresent(FlexString.self, forKey: .season)
        episodeNum = try? container.decodeIfPresent(FlexString.self, forKey: .episodeNum)

        // `info` is sometimes an object, sometimes an empty array.
        if let info = try? container.nestedContainer(keyedBy: InfoKeys.self, forKey: .info) {
            plot = try? info.decodeIfPresent(String.self, forKey: .plot)
            durationSecs = (try? info.decodeIfPresent(FlexString.self, forKey: .durationSecs))??.intValue
            movieImage = try? info.decodeIfPresent(String.self, forKey: .movieImage)
        } else {
            plot = nil
            durationSecs = nil
            movieImage = nil
        }
    }
}

struct XtreamSeriesInfo: Decodable {
    let episodes: [String: [XtreamEpisode]]

    private enum CodingKeys: String, CodingKey {
        case episodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let dict = try? container.decode([String: [XtreamEpisode]].self, forKey: .episodes) {
            episodes = dict
        } else if let array = try? container.decode([[XtreamEpisode]].self, forKey: .episodes) {
            var dict: [String: [XtreamEpisode]] = [:]
            for group in array {
                let season = group.first?.season?.value ?? "1"
                dict[season, default: []].append(contentsOf: group)
            }
            episodes = dict
        } else {
            episodes = [:]
        }
    }
}

struct XtreamVODInfo: Decodable {
    let info: Info?

    struct Info: Decodable {
        let plot: String?
        let genre: String?
        let cast: String?
        let director: String?
        let duration: String?
        let releaseDate: String?

        enum CodingKeys: String, CodingKey {
            case plot, genre, cast, director, duration
            case releaseDate = "releasedate"
        }
    }
}

struct XtreamEPGResponse: Decodable {
    let epgListings: [Listing]?

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }

    struct Listing: Decodable {
        let title: String?
        let description: String?
        let startTimestamp: FlexString?
        let stopTimestamp: FlexString?

        enum CodingKeys: String, CodingKey {
            case title, description
            case startTimestamp = "start_timestamp"
            case stopTimestamp = "stop_timestamp"
        }

        func program(channelID: String) -> EPGProgram? {
            guard let start = startTimestamp?.doubleValue,
                  let stop = stopTimestamp?.doubleValue
            else { return nil }
            return EPGProgram(
                channelID: channelID,
                title: decodeBase64(title) ?? "Unknown",
                desc: decodeBase64(description),
                start: Date(timeIntervalSince1970: start),
                end: Date(timeIntervalSince1970: stop)
            )
        }

        private func decodeBase64(_ string: String?) -> String? {
            guard let string else { return nil }
            guard let data = Data(base64Encoded: string),
                  let decoded = String(data: data, encoding: .utf8)
            else { return string }
            return decoded
        }
    }
}
