import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(ContentStore.self) private var store
    @Environment(PlaybackCoordinator.self) private var playback
    @Query private var playlists: [PlaylistEntity]

    private var activePlaylistID: UUID? {
        (playlists.first(where: \.isActive) ?? playlists.first)?.id
    }

    var body: some View {
        @Bindable var playback = playback

        MainTabView()
            .fullScreenCover(item: $playback.current) { item in
                PlayerView(item: item)
            }
            .task(id: activePlaylistID) {
                let active = playlists.first(where: \.isActive) ?? playlists.first
                await store.activateIfNeeded(active.flatMap(PlaylistConfig.init(entity:)))
            }
    }
}
