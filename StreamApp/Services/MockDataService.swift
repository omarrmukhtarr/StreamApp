import Foundation

/// Sample content shown while no playlist is configured, so every screen of
/// the app is browsable — and playable — out of the box.
///
/// Every stream URL below was verified reachable (HTTP 200, `video/*`
/// content type) against public, license-free test assets:
///   • Live channels  → Apple's HLS example streams (`devstreaming-cdn.apple.com`)
///   • Movies/Episodes → W3C, MDN, Blender open movies, and Mux test HLS
///   • Posters/logos   → picsum.photos deterministic image service
enum MockDataService {

    struct DemoContent {
        let channels: [LiveChannel]
        let movies: [Movie]
        let series: [Series]
        let episodesBySeriesID: [String: [Episode]]
        let epg: EPGSnapshot
    }

    private static let playlistID = "demo"

    // MARK: - Verified Streams

    /// Live HLS streams (Apple example CDN). AVPlayer follows the 302 on the
    /// first entry transparently.
    private static let liveStreams = [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_hevc/master.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8"
    ]

    /// On-demand (VOD) streams for movies and episodes — a mix of progressive
    /// MP4 and HLS, all confirmed playable.
    private static let vodStreams = [
        "https://media.w3.org/2010/05/sintel/trailer.mp4",
        "https://media.w3.org/2010/05/bunny/movie.mp4",
        "https://media.w3.org/2010/05/bunny/trailer.mp4",
        "https://media.w3.org/2010/05/video/movie_300.mp4",
        "https://www.w3schools.com/html/mov_bbb.mp4",
        "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4",
        "https://download.blender.org/durian/trailer/sintel_trailer-720p.mp4",
        "https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4",
        "https://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4",
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        "https://test-streams.mux.dev/pts_shift/master.m3u8"
    ]

    /// A stable, deterministic poster/logo for any seed string.
    private static func imageURL(seed: String, width: Int = 300, height: Int = 450) -> URL? {
        let safe = seed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? seed
        return URL(string: "https://picsum.photos/seed/\(safe)/\(width)/\(height)")
    }

    /// Round-robins a VOD stream so every item gets a working, playable URL.
    private static func vodStream(_ index: Int) -> URL? {
        URL(string: vodStreams[index % vodStreams.count])
    }

    // MARK: - Entry Point

    static func demoContent() -> DemoContent {
        let channels = makeChannels()
        return DemoContent(
            channels: channels,
            movies: makeMovies(),
            series: makeSeries(),
            episodesBySeriesID: makeEpisodes(),
            epg: makeEPG(for: channels)
        )
    }

    // MARK: - Live Channels

    private static let channelSeeds: [(name: String, group: String)] = [
        ("Global News 24", "News"),
        ("Business Now", "News"),
        ("Weather Center", "News"),
        ("Champions Sports", "Sports"),
        ("Motor Arena", "Sports"),
        ("Prime Cinema", "Entertainment"),
        ("Comedy Hub", "Entertainment"),
        ("Drama One", "Entertainment"),
        ("Kids Planet", "Kids"),
        ("Cartoon City", "Kids"),
        ("Hits Music TV", "Music"),
        ("Wild Earth", "Documentaries")
    ]

    private static func makeChannels() -> [LiveChannel] {
        channelSeeds.enumerated().compactMap { index, seed in
            guard let url = URL(string: liveStreams[index % liveStreams.count]) else { return nil }
            return LiveChannel(
                id: "\(playlistID)|live|\(index + 1)",
                number: index + 1,
                name: seed.name,
                logoURL: imageURL(seed: "logo-\(seed.name)", width: 200, height: 200),
                streamURL: url,
                group: seed.group,
                epgChannelID: "demo.channel.\(index + 1)"
            )
        }
    }

    // MARK: - Movies

    private static let movieSeeds: [(seed: String, title: String, group: String, year: String, rating: Double, plot: String)] = [
        ("BigBuckBunny", "Big Buck Bunny", "Animation", "2008", 7.9,
         "A gentle giant rabbit takes good-natured revenge on three bullying rodents in this Blender Foundation classic."),
        ("ElephantsDream", "Elephants Dream", "Animation", "2006", 6.9,
         "Two strange characters explore a surreal, ever-shifting machine world — the first open movie ever made."),
        ("Sintel", "Sintel", "Fantasy", "2010", 7.5,
         "A lonely girl crosses mountains and deserts searching for the baby dragon she once rescued and lost."),
        ("TearsOfSteel", "Tears of Steel", "Sci-Fi", "2012", 6.5,
         "In a future Amsterdam, a group of warriors and scientists fights to save the world from destructive robots."),
        ("ForBiggerBlazes", "For Bigger Blazes", "Action", "2014", 6.2,
         "A short, explosive showcase of fire and spectacle, made for the biggest screens."),
        ("ForBiggerEscapes", "For Bigger Escapes", "Action", "2014", 6.0,
         "Daring getaways and narrow misses in a fast-paced action short."),
        ("ForBiggerFun", "For Bigger Fun", "Comedy", "2014", 6.4,
         "A lighthearted romp celebrating fun in all shapes and sizes."),
        ("ForBiggerJoyrides", "For Bigger Joyrides", "Action", "2014", 6.1,
         "High-speed thrills as joyriders take to the streets."),
        ("ForBiggerMeltdowns", "For Bigger Meltdowns", "Comedy", "2014", 5.9,
         "When everything goes wrong at once, all you can do is laugh."),
        ("SubaruOutback", "Outback: Street & Dirt", "Adventure", "2015", 6.7,
         "An all-terrain road trip pushing a rally-bred wagon across asphalt and gravel."),
        ("VolkswagenGTI", "GTI: The Review", "Adventure", "2015", 6.3,
         "A hands-on look at a hot hatch icon, from track laps to daily driving."),
        ("Bullrun", "Going on Bullrun", "Adventure", "2015", 6.6,
         "Join the convoy on a legendary cross-country rally."),
        ("CarForAGrand", "A Car for a Grand", "Documentary", "2015", 6.8,
         "Bargain hunting on four wheels: what does a thousand bucks really buy?")
    ]

    private static func makeMovies() -> [Movie] {
        movieSeeds.enumerated().compactMap { index, seed in
            guard let url = vodStream(index) else { return nil }
            return Movie(
                id: "\(playlistID)|movie|\(seed.seed)",
                title: seed.title,
                posterURL: imageURL(seed: seed.seed),
                streamURL: url,
                group: seed.group,
                year: seed.year,
                rating: seed.rating,
                addedAt: Date().addingTimeInterval(TimeInterval(-index * 86_400)),
                vodID: nil,
                plot: seed.plot
            )
        }
    }

    // MARK: - Series

    private static let seriesSeeds: [(id: String, title: String, group: String, plot: String, episodes: [(title: String, season: Int, episode: Int)])] = [
        (
            "blender-chronicles", "Blender Chronicles", "Animation",
            "An anthology of landmark open movies, each pushing the boundaries of independent animation.",
            [
                ("The Gentle Giant", 1, 1),
                ("The Machine", 1, 2),
                ("The Search", 2, 1),
                ("The Last Stand", 2, 2)
            ]
        ),
        (
            "road-trips", "Road Trips", "Adventure",
            "Every episode, a new machine and a new horizon: rallies, reviews and back-road adventures.",
            [
                ("Street & Dirt", 1, 1),
                ("Hot Hatch", 1, 2),
                ("Bullrun", 1, 3),
                ("Grand Designs", 1, 4)
            ]
        ),
        (
            "bigger-stories", "Bigger Stories", "Shorts",
            "Bite-sized tales that go big: blazes, escapes, joyrides and meltdowns.",
            [
                ("Blazes", 1, 1),
                ("Escapes", 1, 2),
                ("Fun", 1, 3),
                ("Joyrides", 1, 4),
                ("Meltdowns", 1, 5)
            ]
        )
    ]

    private static func makeSeries() -> [Series] {
        seriesSeeds.map { seed in
            Series(
                id: "\(playlistID)|series|\(seed.id)",
                title: seed.title,
                posterURL: imageURL(seed: seed.id),
                group: seed.group,
                plot: seed.plot,
                rating: 7.2,
                releaseDate: "2024",
                seriesID: nil
            )
        }
    }

    private static func makeEpisodes() -> [String: [Episode]] {
        var result: [String: [Episode]] = [:]
        var streamIndex = 0
        for seed in seriesSeeds {
            let seriesKey = "\(playlistID)|series|\(seed.id)"
            result[seriesKey] = seed.episodes.compactMap { episode in
                defer { streamIndex += 1 }
                guard let url = vodStream(streamIndex) else { return nil }
                return Episode(
                    id: "\(playlistID)|ep|\(seed.id)-s\(episode.season)e\(episode.episode)",
                    title: episode.title,
                    season: episode.season,
                    episodeNumber: episode.episode,
                    streamURL: url,
                    plot: nil,
                    durationSeconds: 60,
                    imageURL: imageURL(seed: "\(seed.id)-\(episode.season)-\(episode.episode)", width: 320, height: 180)
                )
            }
        }
        return result
    }

    // MARK: - EPG

    private static let programTitlesByGroup: [String: [String]] = [
        "News": ["Morning Briefing", "World Report", "Market Watch", "The Interview", "Evening Headlines", "Night Desk"],
        "Sports": ["Matchday Live", "The Halftime Show", "Legends Replay", "Race Center", "Extra Time", "Top Plays"],
        "Entertainment": ["Prime Feature", "The Late Lounge", "Star Stories", "Encore Cinema", "Backstage Pass", "Trivia Night"],
        "Kids": ["Sunrise Cartoons", "Puzzle Party", "Story Corner", "Adventure Club", "Silly Science", "Bedtime Tales"],
        "Music": ["Wake-Up Hits", "Top 20 Countdown", "Unplugged", "Throwback Hour", "Fresh Drops", "Midnight Mix"],
        "Documentaries": ["Ocean Giants", "Hidden Cities", "Cosmos Uncovered", "Wildlife Diaries", "Engineering Marvels", "Ancient Trails"]
    ]

    private static func makeEPG(for channels: [LiveChannel]) -> EPGSnapshot {
        var byChannel: [String: [EPGProgram]] = [:]
        let slotLength: TimeInterval = 45 * 60
        let calendar = Calendar.current
        let anchor = calendar.date(
            bySettingHour: calendar.component(.hour, from: .now),
            minute: 0,
            second: 0,
            of: .now
        ) ?? .now
        let firstSlot = anchor.addingTimeInterval(-2 * 3600)

        for (channelIndex, channel) in channels.enumerated() {
            guard let epgID = channel.epgChannelID else { continue }
            let titles = programTitlesByGroup[channel.group] ?? ["Featured Program"]
            var programs: [EPGProgram] = []

            for slot in 0..<20 {
                let start = firstSlot.addingTimeInterval(Double(slot) * slotLength)
                let title = titles[(slot + channelIndex) % titles.count]
                programs.append(
                    EPGProgram(
                        channelID: epgID,
                        title: title,
                        desc: "\(title) on \(channel.name) — part of today's demo guide.",
                        start: start,
                        end: start.addingTimeInterval(slotLength)
                    )
                )
            }
            byChannel[epgID.lowercased()] = programs
        }
        return EPGSnapshot(programsByChannel: byChannel, updatedAt: .now)
    }
}
