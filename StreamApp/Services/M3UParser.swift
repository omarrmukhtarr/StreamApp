import Foundation

struct M3UParseResult {
    var channels: [LiveChannel] = []
    var movies: [Movie] = []
    var series: [Series] = []
    var episodesBySeriesID: [String: [Episode]] = [:]
    var epgURL: URL?
}

/// Parses M3U/M3U8 playlists, splitting entries into live channels, movies
/// and series episodes using container-extension and SxxExx heuristics.
enum M3UParser {

    private static let movieExtensions: Set<String> = ["mp4", "mkv", "avi", "mov", "m4v", "flv", "wmv", "webm"]

    private static let seasonEpisodeRegex = try? NSRegularExpression(
        pattern: #"(?i)^(.*?)[\s.\-_]*S(\d{1,2})[\s.\-_]*E(\d{1,4})"#
    )

    static func parse(_ text: String, playlistID: String) -> M3UParseResult {
        var result = M3UParseResult()
        var pendingInfo: (attributes: [String: String], title: String)?
        var pendingGroup: String?
        var channelIndex = 0

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#EXTM3U") {
                let attributes = parseAttributes(from: line)
                if let tvg = attributes["url-tvg"] ?? attributes["x-tvg-url"],
                   let url = URL(string: tvg) {
                    result.epgURL = url
                }
            } else if line.hasPrefix("#EXTINF") {
                pendingInfo = parseEXTINF(line)
            } else if line.hasPrefix("#EXTGRP:") {
                pendingGroup = String(line.dropFirst("#EXTGRP:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("#") {
                continue
            } else if let info = pendingInfo, let url = URL(string: line) {
                channelIndex += 1
                append(
                    url: url,
                    attributes: info.attributes,
                    title: info.title,
                    fallbackGroup: pendingGroup,
                    index: channelIndex,
                    playlistID: playlistID,
                    into: &result
                )
                pendingInfo = nil
                pendingGroup = nil
            }
        }

        result.series.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return result
    }

    // MARK: - Entry Classification

    private static func append(
        url: URL,
        attributes: [String: String],
        title: String,
        fallbackGroup: String?,
        index: Int,
        playlistID: String,
        into result: inout M3UParseResult
    ) {
        let group = attributes["group-title"] ?? fallbackGroup ?? "Uncategorized"
        let logo = attributes["tvg-logo"].flatMap(URL.init(string:))
        let name = title.isEmpty ? (attributes["tvg-name"] ?? "Unknown") : title
        let ext = url.pathExtension.lowercased()

        if let match = seasonEpisode(in: name) {
            let seriesTitle = match.title.isEmpty ? name : match.title
            let seriesID = "\(playlistID)|series|\(seriesTitle.lowercased())"
            if !result.episodesBySeriesID.keys.contains(seriesID) {
                result.series.append(
                    Series(
                        id: seriesID,
                        title: seriesTitle,
                        posterURL: logo,
                        group: group,
                        plot: nil,
                        rating: nil,
                        releaseDate: nil,
                        seriesID: nil
                    )
                )
            }
            let episode = Episode(
                id: "\(playlistID)|ep|\(url.absoluteString)",
                title: name,
                season: match.season,
                episodeNumber: match.episode,
                streamURL: url,
                plot: nil,
                durationSeconds: nil,
                imageURL: logo
            )
            result.episodesBySeriesID[seriesID, default: []].append(episode)
        } else if movieExtensions.contains(ext) {
            result.movies.append(
                Movie(
                    id: "\(playlistID)|movie|\(url.absoluteString)",
                    title: name,
                    posterURL: logo,
                    streamURL: url,
                    group: group,
                    year: nil,
                    rating: nil,
                    addedAt: nil,
                    vodID: nil
                )
            )
        } else {
            result.channels.append(
                LiveChannel(
                    id: "\(playlistID)|live|\(url.absoluteString)",
                    number: index,
                    name: name,
                    logoURL: logo,
                    streamURL: url,
                    group: group,
                    epgChannelID: attributes["tvg-id"]
                )
            )
        }
    }

    private static func seasonEpisode(in name: String) -> (title: String, season: Int, episode: Int)? {
        guard let regex = seasonEpisodeRegex else { return nil }
        let range = NSRange(name.startIndex..., in: name)
        guard let match = regex.firstMatch(in: name, range: range),
              let titleRange = Range(match.range(at: 1), in: name),
              let seasonRange = Range(match.range(at: 2), in: name),
              let episodeRange = Range(match.range(at: 3), in: name),
              let season = Int(name[seasonRange]),
              let episode = Int(name[episodeRange])
        else { return nil }

        let title = name[titleRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, season, episode)
    }

    // MARK: - Line Parsing

    private static func parseEXTINF(_ line: String) -> (attributes: [String: String], title: String) {
        let attributes = parseAttributes(from: line)
        // The display title follows the last comma outside of quotes.
        var title = ""
        if let commaIndex = lastCommaOutsideQuotes(in: line) {
            title = String(line[line.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
        }
        return (attributes, title)
    }

    private static func lastCommaOutsideQuotes(in line: String) -> String.Index? {
        var inQuotes = false
        var lastComma: String.Index?
        var index = line.startIndex
        while index < line.endIndex {
            let char = line[index]
            if char == "\"" {
                inQuotes.toggle()
            } else if char == ",", !inQuotes {
                lastComma = index
            }
            index = line.index(after: index)
        }
        return lastComma
    }

    /// Extracts `key="value"` pairs from a line.
    private static func parseAttributes(from line: String) -> [String: String] {
        var attributes: [String: String] = [:]
        var index = line.startIndex

        while index < line.endIndex {
            guard let equalsQuote = line.range(of: "=\"", range: index..<line.endIndex) else { break }
            // Walk backwards from '=' to find the start of the key.
            var keyStart = equalsQuote.lowerBound
            while keyStart > line.startIndex {
                let previous = line.index(before: keyStart)
                let char = line[previous]
                if char.isLetter || char.isNumber || char == "-" || char == "_" {
                    keyStart = previous
                } else {
                    break
                }
            }
            let key = String(line[keyStart..<equalsQuote.lowerBound]).lowercased()
            guard let closingQuote = line.range(of: "\"", range: equalsQuote.upperBound..<line.endIndex) else { break }
            let value = String(line[equalsQuote.upperBound..<closingQuote.lowerBound])
            if !key.isEmpty {
                attributes[key] = value
            }
            index = closingQuote.upperBound
        }
        return attributes
    }
}
