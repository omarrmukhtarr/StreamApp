import SwiftData
import SwiftUI

struct MovieDetailView: View {
    @Environment(ContentStore.self) private var store
    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.modelContext) private var modelContext

    @State private var movie: Movie

    init(movie: Movie) {
        _movie = State(initialValue: movie)
    }

    private var profileID: UUID { profiles.currentID ?? UUID() }

    private var progress: WatchProgressEntity? {
        Library.watchProgress(for: movie.id, profileID: profileID, in: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actionButtons

                if let plot = movie.plot, !plot.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synopsis")
                            .font(.headline)
                        Text(plot)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                detailRows
            }
            .padding(.vertical)
        }
        .appBackground()
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetailsIfNeeded() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            RemoteImage(url: movie.posterURL, systemFallback: "film")
                .frame(width: 140, height: 210)
                .clipShape(.rect(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Text(movie.title)
                    .font(.title2.bold())
                    .lineLimit(3)

                if let rating = movie.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                }

                Text(movie.group)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)

                if let progress, progress.fractionWatched > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressBar(progress: progress.fractionWatched)
                            .frame(maxWidth: 140)
                        Text("\(Int(progress.fractionWatched * 100))% watched")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    playback.play(movie.playable)
                } label: {
                    Label(progress != nil ? "Resume" : "Play", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.brandPrimary)

                FavoriteToggleButton(contentKey: movie.id, kind: .movie, profileID: profileID)

                DownloadButton(item: movie.playable, profileID: profileID)
            }

            if let trailer = movie.trailerPlayable {
                Button {
                    playback.play(trailer)
                } label: {
                    Label("Watch Trailer", systemImage: "movieclapper")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal)
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let genre = movie.genre, !genre.isEmpty {
                detailRow(label: "Genre", value: genre)
            }
            if let cast = movie.cast, !cast.isEmpty {
                detailRow(label: "Cast", value: cast)
            }
            if let duration = movie.durationText, !duration.isEmpty {
                detailRow(label: "Duration", value: duration)
            }
            if let year = movie.year, !year.isEmpty {
                detailRow(label: "Released", value: year)
            }
        }
        .padding(.horizontal)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    /// Fetches extended Xtream metadata (plot, cast, genre) on demand.
    private func loadDetailsIfNeeded() async {
        guard movie.plot == nil,
              let vodID = movie.vodID,
              let config = store.activeConfig,
              config.kind == .xtream
        else { return }

        let service = XtreamService(config: config)
        guard let info = try? await service.fetchVODInfo(vodID: vodID).info else { return }
        movie.plot = info.plot
        movie.genre = info.genre
        movie.cast = info.cast
        movie.durationText = info.duration
    }
}
