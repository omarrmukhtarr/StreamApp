import Foundation
import Observation

@MainActor
@Observable
final class LiveTVViewModel {
    var selectedGroup: String?
    var searchText = ""

    func filteredChannels(from channels: [LiveChannel]) -> [LiveChannel] {
        var result = channels
        if let selectedGroup {
            result = result.filter { $0.group == selectedGroup }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return result
    }
}
