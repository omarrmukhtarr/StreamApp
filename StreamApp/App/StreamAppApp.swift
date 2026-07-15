import AVFAudio
import SwiftData
import SwiftUI

@main
struct StreamAppApp: App {
    private let container: ModelContainer
    @State private var contentStore = ContentStore()
    @State private var playback = PlaybackCoordinator()
    @State private var profiles = ProfileStore()
    @State private var downloads = DownloadManager()

    init() {
        container = Self.makeContainer()

        // Generous cache for channel logos and posters.
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024
        )
        // `.playback` keeps audio going for background audio and Picture in Picture.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)

        downloads.configure(container: container)
    }

    /// Creates the SwiftData container. If the on-disk store is incompatible
    /// (e.g. after a schema change during development), the store is removed
    /// and recreated so the app can still launch, rather than crashing.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            PlaylistEntity.self,
            FavoriteEntity.self,
            WatchProgressEntity.self,
            ProfileEntity.self,
            DownloadEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Incompatible existing store — wipe it and try once more.
            deleteStoreFiles(at: configuration.url)
            if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
                return container
            }
            // Last resort so the app is never dead on launch.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }

    private static func deleteStoreFiles(at url: URL) {
        let manager = FileManager.default
        // SwiftData/SQLite keeps sidecar files alongside the main store.
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            if manager.fileExists(atPath: path) {
                try? manager.removeItem(atPath: path)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(contentStore)
                .environment(playback)
                .environment(profiles)
                .environment(downloads)
                .preferredColorScheme(.dark)
                .tint(.brandPrimary)
        }
        .modelContainer(container)
    }
}
