import SwiftData
import SwiftUI

struct DownloadsView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(PlaybackCoordinator.self) private var playback
    @Environment(DownloadManager.self) private var downloads
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DownloadEntity.createdAt, order: .reverse) private var allDownloads: [DownloadEntity]

    private var myDownloads: [DownloadEntity] {
        allDownloads.filter { $0.profileID == profiles.currentID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if myDownloads.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Movies you download for offline viewing appear here.")
                    )
                } else {
                    List {
                        ForEach(myDownloads) { download in
                            row(download)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteRows)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .appBackground()
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ download: DownloadEntity) -> some View {
        let isReady = download.state == .completed
        Button {
            if let playable = download.playable { playback.play(playable) }
        } label: {
            HStack(spacing: 12) {
                RemoteImage(url: download.artworkURLString.flatMap(URL.init(string:)), systemFallback: "film")
                    .frame(width: 60, height: 84)
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(download.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(statusText(download))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if download.state == .downloading {
                        ProgressBar(progress: downloads.progress(forDownloadID: download.id, fallback: download.progress))
                            .frame(maxWidth: 160)
                    }
                }

                Spacer()

                Image(systemName: isReady ? "play.circle.fill" : "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(isReady ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(.secondary))
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
    }

    private func statusText(_ download: DownloadEntity) -> String {
        switch download.state {
        case .completed: "Downloaded · Ready offline"
        case .failed: "Download failed — swipe to remove"
        case .downloading: "Downloading \(Int(downloads.progress(forDownloadID: download.id, fallback: download.progress) * 100))%"
        }
    }

    private func deleteRows(_ offsets: IndexSet) {
        for index in offsets {
            downloads.delete(myDownloads[index])
        }
    }
}
