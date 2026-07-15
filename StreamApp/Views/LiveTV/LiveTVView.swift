import SwiftData
import SwiftUI

struct LiveTVView: View {
    @Environment(ContentStore.self) private var store
    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteEntity]

    @State private var model = LiveTVViewModel()

    private var profileID: UUID { profiles.currentID ?? UUID() }

    private var favoriteKeys: Set<String> {
        Set(favorites.filter { $0.profileID == profiles.currentID }.map(\.contentKey))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .idle, .loading:
                    LoadingStateView(message: "Loading channels…")
                case .failed(let message):
                    ErrorStateView(message: message) { await store.refresh() }
                case .loaded:
                    channelList
                }
            }
            .appBackground()
            .navigationTitle("Live TV")
        }
    }

    private var channelList: some View {
        let channels = model.filteredChannels(from: store.channels)

        return VStack(spacing: 0) {
            GroupChipsBar(groups: store.channelGroups, selection: $model.selectedGroup)

            if channels.isEmpty {
                ContentUnavailableView(
                    "No Channels",
                    systemImage: "tv.slash",
                    description: Text("No live channels match this filter.")
                )
            } else {
                List(channels) { channel in
                    Button {
                        playback.play(channel.playable)
                    } label: {
                        ChannelRow(
                            channel: channel,
                            nowPlaying: store.epg.current(for: channel.epgChannelID),
                            isFavorite: favoriteKeys.contains(channel.id)
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.white.opacity(0.08))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        favoriteSwipeButton(for: channel)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await store.refresh() }
            }
        }
        .searchable(text: $model.searchText, prompt: "Filter channels")
    }

    @ViewBuilder
    private func favoriteSwipeButton(for channel: LiveChannel) -> some View {
        let isFavorite = favoriteKeys.contains(channel.id)
        Button {
            toggleFavorite(channel)
        } label: {
            Label(
                isFavorite ? "Unfavorite" : "Favorite",
                systemImage: isFavorite ? "star.slash" : "star"
            )
        }
        .tint(isFavorite ? .gray : .yellow)
    }

    private func toggleFavorite(_ channel: LiveChannel) {
        Library.toggleFavorite(contentKey: channel.id, kind: .live, profileID: profileID, in: modelContext)
    }
}
