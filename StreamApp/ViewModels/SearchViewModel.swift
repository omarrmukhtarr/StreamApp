import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var searchText = ""

    struct Results {
        var channels: [LiveChannel] = []
        var movies: [Movie] = []
        var series: [Series] = []

        var isEmpty: Bool { channels.isEmpty && movies.isEmpty && series.isEmpty }
    }

    func results(from store: ContentStore, limit: Int = 30) -> Results {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return Results() }

        return Results(
            channels: Array(
                store.channels
                    .filter { $0.name.localizedCaseInsensitiveContains(query) }
                    .prefix(limit)
            ),
            movies: Array(
                store.movies
                    .filter { $0.title.localizedCaseInsensitiveContains(query) }
                    .prefix(limit)
            ),
            series: Array(
                store.series
                    .filter { $0.title.localizedCaseInsensitiveContains(query) }
                    .prefix(limit)
            )
        )
    }
}
