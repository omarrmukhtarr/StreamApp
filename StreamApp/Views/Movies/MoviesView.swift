import SwiftUI

struct MoviesView: View {
    @Environment(ContentStore.self) private var store
    @State private var model = MoviesViewModel()

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .idle, .loading:
                    LoadingStateView(message: "Loading movies…")
                case .failed(let message):
                    ErrorStateView(message: message) { await store.refresh() }
                case .loaded:
                    grid
                }
            }
            .appBackground()
            .navigationTitle("Movies")
        }
    }

    private var grid: some View {
        let movies = model.filteredMovies(from: store.movies)

        return VStack(spacing: 0) {
            GroupChipsBar(groups: store.movieGroups, selection: $model.selectedGroup)

            if movies.isEmpty {
                ContentUnavailableView(
                    "No Movies",
                    systemImage: "film",
                    description: Text("No movies match this filter.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(movies) { movie in
                            NavigationLink {
                                MovieDetailView(movie: movie)
                            } label: {
                                PosterCard(
                                    title: movie.title,
                                    imageURL: movie.posterURL,
                                    subtitle: movie.year,
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
        .searchable(text: $model.searchText, prompt: "Filter movies")
    }
}
