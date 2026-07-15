import Foundation

/// Sample content shown while no playlist is configured, so every screen of
/// the app is browsable out of the box. Streams are public test assets
/// (Apple HLS examples and the Google sample-video bucket), so playback works.
enum MockDataService {

    struct DemoContent {
        let channels: [LiveChannel]
        let movies: [Movie]
        let series: [Series]
        let episodesBySeriesID: [String: [Episode]]
        let epg: EPGSnapshot
    }

    private static let playlistID = "demo"

    private static let hlsStreams = [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_hevc/master.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
    ]

    private static let sampleBucket = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample"

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
            guard let url = URL(string: hlsStreams[index % hlsStreams.count]) else { return nil }
            return LiveChannel(
                id: "\(playlistID)|live|\(index + 1)",
                number: index + 1,
                name: seed.name,
                logoURL: nil,
                streamURL: url,
                group: seed.group,
                epgChannelID: "demo.channel.\(index + 1)"
            )
        }
    }

    // MARK: - Movies

    private static let movieSeeds: [(file: String, title: String, group: String, year: String, rating: Double, plot: String)] = [
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
        ("SubaruOutbackOnStreetAndDirt", "Outback: Street & Dirt", "Adventure", "2015", 6.7,
         "An all-terrain road trip pushing a rally-bred wagon across asphalt and gravel."),
        ("VolkswagenGTIReview", "GTI: The Review", "Adventure", "2015", 6.3,
         "A hands-on look at a hot hatch icon, from track laps to daily driving."),
        ("WeAreGoingOnBullrun", "Going on Bullrun", "Adventure", "2015", 6.6,
         "Join the convoy on a legendary cross-country rally."),
        ("WhatCarCanYouGetForAGrand", "A Car for a Grand", "Documentary", "2015", 6.8,
         "Bargain hunting on four wheels: what does a thousand bucks really buy?")
    ]

    private static func makeMovies() -> [Movie] {
        movieSeeds.enumerated().compactMap { index, seed in
            guard let url = URL(string: "\(sampleBucket)/\(seed.file).mp4") else { return nil }
            return Movie(
                id: "\(playlistID)|movie|\(seed.file)",
                title: seed.title,
                posterURL: URL(string: "\(sampleBucket)/images/\(seed.file).jpg"),
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

    private static let seriesSeeds: [(id: String, title: String, group: String, poster: String, plot: String, episodes: [(file: String, title: String, season: Int, episode: Int)])] = [
        (
            "blender-chronicles", "Blender Chronicles", "Animation", "Sintel",
            "An anthology of landmark open movies, each pushing the boundaries of independent animation.",
            [
                ("BigBuckBunny", "The Gentle Giant", 1, 1),
                ("ElephantsDream", "The Machine", 1, 2),
                ("Sintel", "The Search", 2, 1),
                ("TearsOfSteel", "The Last Stand", 2, 2)
            ]
        ),
        (
            "road-trips", "Road Trips", "Adventure", "SubaruOutbackOnStreetAndDirt",
            "Every episode, a new machine and a new horizon: rallies, reviews and back-road adventures.",
            [
                ("SubaruOutbackOnStreetAndDirt", "Street & Dirt", 1, 1),
                ("VolkswagenGTIReview", "Hot Hatch", 1, 2),
                ("WeAreGoingOnBullrun", "Bullrun", 1, 3),
                ("WhatCarCanYouGetForAGrand", "Grand Designs", 1, 4)
            ]
        ),
        (
            "bigger-stories", "Bigger Stories", "Shorts", "ForBiggerFun",
            "Bite-sized tales that go big: blazes, escapes, joyrides and meltdowns.",
            [
                ("ForBiggerBlazes", "Blazes", 1, 1),
                ("ForBiggerEscapes", "Escapes", 1, 2),
                ("ForBiggerFun", "Fun", 1, 3),
                ("ForBiggerJoyrides", "Joyrides", 1, 4),
                ("ForBiggerMeltdowns", "Meltdowns", 1, 5)
            ]
        )
    ]

    private static func makeSeries() -> [Series] {
        seriesSeeds.map { seed in
            Series(
                id: "\(playlistID)|series|\(seed.id)",
                title: seed.title,
                posterURL: URL(string: "\(sampleBucket)/images/\(seed.poster).jpg"),
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
        for seed in seriesSeeds {
            let seriesKey = "\(playlistID)|series|\(seed.id)"
            result[seriesKey] = seed.episodes.compactMap { episode in
                guard let url = URL(string: "\(sampleBucket)/\(episode.file).mp4") else { return nil }
                return Episode(
                    id: "\(playlistID)|ep|\(seed.id)-s\(episode.season)e\(episode.episode)",
                    title: episode.title,
                    season: episode.season,
                    episodeNumber: episode.episode,
                    streamURL: url,
                    plot: nil,
                    durationSeconds: 600,
                    imageURL: URL(string: "\(sampleBucket)/images/\(episode.file).jpg")
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
