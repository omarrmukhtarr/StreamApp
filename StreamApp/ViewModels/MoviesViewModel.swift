import Foundation
import Observation

@MainActor
@Observable
final class MoviesViewModel {
    var selectedGroup: String?
    var searchText = ""

    func filteredMovies(from movies: [Movie]) -> [Movie] {
        var result = movies
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
