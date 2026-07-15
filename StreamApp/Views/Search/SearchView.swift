import SwiftUI

struct SearchView: View {
    @Environment(ContentStore.self) private var store
    @Environment(PlaybackCoordinator.self) private var playback
    @State private var model = SearchViewModel()

    var body: some View {
        NavigationStack {
            content
                .appBackground()
                .navigationTitle("Search")
                .searchable(text: $model.searchText, prompt: "Channels, movies, series")
        }
    }

    @ViewBuilder
    private var content: some View {
        let results = model.results(from: store)
        let query = model.searchText.trimmingCharacters(in: .whitespaces)

        if query.count < 2 {
            ContentUnavailableView(
                "Search Everything",
                systemImage: "magnifyingglass",
                description: Text("Find live channels, movies and series across your playlist.")
            )
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                if !results.channels.isEmpty {
                    Section("Live Channels") {
                        ForEach(results.channels) { channel in
                            Button {
                                playback.play(channel.playable)
                            } label: {
                                ChannelRow(
                                    channel: channel,
                                    nowPlaying: store.epg.current(for: channel.epgChannelID),
                                    isFavorite: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.clear)
                    }
                }

                if !results.movies.isEmpty {
                    Section("Movies") {
                        ForEach(results.movies) { movie in
                            NavigationLink {
                                MovieDetailView(movie: movie)
                            } label: {
                                searchRow(title: movie.title, subtitle: movie.group, imageURL: movie.posterURL, icon: "film")
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }

                if !results.series.isEmpty {
                    Section("Series") {
                        ForEach(results.series) { series in
                            NavigationLink {
                                SeriesDetailView(series: series)
                            } label: {
                                searchRow(title: series.title, subtitle: series.group, imageURL: series.posterURL, icon: "rectangle.stack")
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func searchRow(title: String, subtitle: String, imageURL: URL?, icon: String) -> some View {
        HStack(spacing: 12) {
            RemoteImage(url: imageURL, systemFallback: icon)
                .frame(width: 44, height: 62)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
