import SwiftUI

struct SeriesView: View {
    @Environment(ContentStore.self) private var store
    @State private var model = SeriesViewModel()

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .idle, .loading:
                    LoadingStateView(message: "Loading series…")
                case .failed(let message):
                    ErrorStateView(message: message) { await store.refresh() }
                case .loaded:
                    grid
                }
            }
            .appBackground()
            .navigationTitle("Series")
        }
    }

    private var grid: some View {
        let series = model.filteredSeries(from: store.series)

        return VStack(spacing: 0) {
            GroupChipsBar(groups: store.seriesGroups, selection: $model.selectedGroup)

            if series.isEmpty {
                ContentUnavailableView(
                    "No Series",
                    systemImage: "rectangle.stack",
                    description: Text("No series match this filter.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(series) { item in
                            NavigationLink {
                                SeriesDetailView(series: item)
                            } label: {
                                PosterCard(
                                    title: item.title,
                                    imageURL: item.posterURL,
                                    subtitle: item.group,
                                    width: 110
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .refreshable { await store.refresh() }
            }
        }
        .searchable(text: $model.searchText, prompt: "Filter series")
    }
}
