import Foundation
import Observation

@MainActor
@Observable
final class SeriesViewModel {
    var selectedGroup: String?
    var searchText = ""

    func filteredSeries(from series: [Series]) -> [Series] {
        var result = series
        if let selectedGroup {
            result = result.filter { $0.group == selectedGroup }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(query) }
        }
        return result
    }
}

/// Loads and holds the episodes of a single series.
@MainActor
@Observable
final class SeriesDetailViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    let series: Series
    private(set) var state: State = .loading
    private(set) var seasons: [Int] = []
    private(set) var episodesBySeason: [Int: [Episode]] = [:]
    var selectedSeason: Int?

    init(series: Series) {
        self.series = series
    }

    var selectedEpisodes: [Episode] {
        guard let selectedSeason else { return [] }
        return episodesBySeason[selectedSeason] ?? []
    }

    func load(using store: ContentStore) async {
        state = .loading
        do {
            let episodes = try await store.episodes(for: series)
            episodesBySeason = episodes
            seasons = episodes.keys.sorted()
            if selectedSeason == nil || !seasons.contains(selectedSeason ?? -1) {
                selectedSeason = seasons.first
            }
            state = .loaded
        } catch {
            state = .failed("Could not load episodes. Check your connection and try again.")
        }
    }
}
