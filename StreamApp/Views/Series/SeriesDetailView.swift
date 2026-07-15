import SwiftData
import SwiftUI

struct SeriesDetailView: View {
    @Environment(ContentStore.self) private var store
    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.modelContext) private var modelContext
    @Query private var watchProgress: [WatchProgressEntity]

    @State private var model: SeriesDetailViewModel

    init(series: Series) {
        _model = State(initialValue: SeriesDetailViewModel(series: series))
    }

    private var series: Series { model.series }
    private var profileID: UUID { profiles.currentID ?? UUID() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                switch model.state {
                case .loading:
                    ProgressView("Loading episodes…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                case .failed(let message):
                    ErrorStateView(message: message) {
                        await model.load(using: store)
                    }
                    .frame(height: 240)
                case .loaded:
                    episodesSection
                }
            }
            .padding(.vertical)
        }
        .appBackground()
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(using: store) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            RemoteImage(url: series.posterURL, systemFallback: "rectangle.stack")
                .frame(width: 140, height: 210)
                .clipShape(.rect(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Text(series.title)
                    .font(.title2.bold())
                    .lineLimit(3)

                if let rating = series.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                }

                if let releaseDate = series.releaseDate, !releaseDate.isEmpty {
                    Text(releaseDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                FavoriteToggleButton(contentKey: series.id, kind: .series, profileID: profileID, style: .labeled)

                if let plot = series.plot, !plot.isEmpty {
                    Text(plot)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(5)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var episodesSection: some View {
        if model.seasons.isEmpty {
            ContentUnavailableView(
                "No Episodes",
                systemImage: "rectangle.stack",
                description: Text("This series has no episodes available.")
            )
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if model.seasons.count > 1 {
                    seasonPicker
                }

                LazyVStack(spacing: 10) {
                    ForEach(model.selectedEpisodes) { episode in
                        episodeRow(episode)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var seasonPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.seasons, id: \.self) { season in
                    if model.selectedSeason == season {
                        Button("Season \(season)") {}
                            .buttonStyle(.glassProminent)
                            .tint(.brandPrimary)
                    } else {
                        Button("Season \(season)") {
                            model.selectedSeason = season
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .font(.subheadline.weight(.semibold))
    }

    private func episodeRow(_ episode: Episode) -> some View {
        let progress = watchProgress.first { $0.contentKey == episode.id && $0.profileID == profiles.currentID }

        return Button {
            playback.play(episode.playable(in: series))
        } label: {
            HStack(spacing: 12) {
                RemoteImage(url: episode.imageURL ?? series.posterURL, systemFallback: "play.rectangle")
                    .frame(width: 100, height: 60)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .bottom) {
                        if let progress, progress.fractionWatched > 0 {
                            ProgressBar(progress: progress.fractionWatched)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 4)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("E\(episode.episodeNumber)\(episode.title.isEmpty ? "" : " · \(episode.title)")")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let seconds = episode.durationSeconds, seconds > 0 {
                        Text(PlayerViewModel.timeString(Double(seconds)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(LinearGradient.brand)
            }
            .padding(10)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
