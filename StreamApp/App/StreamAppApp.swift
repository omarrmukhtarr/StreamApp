import AVFAudio
import SwiftData
import SwiftUI

@main
struct StreamAppApp: App {
    private let container: ModelContainer
    @State private var contentStore = ContentStore()
    @State private var playback = PlaybackCoordinator()

    init() {
        do {
            container = try ModelContainer(
                for: PlaylistEntity.self, FavoriteEntity.self, WatchProgressEntity.self
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }

        // Generous cache for channel logos and posters.
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024
        )
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(contentStore)
                .environment(playback)
                .preferredColorScheme(.dark)
                .tint(.brandPrimary)
        }
        .modelContainer(container)
    }
}
