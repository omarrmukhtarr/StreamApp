import SwiftData
import SwiftUI

/// Reusable favorite toggle. Owns its own state via `@Query`, so any screen
/// can drop it in with just a content key + kind.
struct FavoriteToggleButton: View {
    enum Style { case icon, labeled }

    let contentKey: String
    let kind: ContentKind
    let profileID: UUID
    var style: Style = .icon

    @Environment(\.modelContext) private var context
    @Query private var matches: [FavoriteEntity]

    init(contentKey: String, kind: ContentKind, profileID: UUID, style: Style = .icon) {
        self.contentKey = contentKey
        self.kind = kind
        self.profileID = profileID
        self.style = style
        let id = "\(profileID.uuidString)|\(contentKey)"
        _matches = Query(filter: #Predicate { $0.id == id })
    }

    private var isFavorite: Bool { !matches.isEmpty }

    var body: some View {
        Button {
            Library.toggleFavorite(contentKey: contentKey, kind: kind, profileID: profileID, in: context)
        } label: {
            switch style {
            case .icon:
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.headline)
                    .foregroundStyle(isFavorite ? .yellow : .primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
            case .labeled:
                Label(isFavorite ? "Favorited" : "Favorite", systemImage: isFavorite ? "star.fill" : "star")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isFavorite ? .yellow : .primary)
            }
        }
        .buttonStyle(.glass)
    }
}

/// Reusable download control that reflects live download state (idle →
/// downloading progress ring → completed) and offers delete when finished.
struct DownloadButton: View {
    let item: PlayableItem
    let profileID: UUID

    @Environment(\.modelContext) private var context
    @Environment(DownloadManager.self) private var downloads
    @Query private var matches: [DownloadEntity]

    init(item: PlayableItem, profileID: UUID) {
        self.item = item
        self.profileID = profileID
        let id = "\(profileID.uuidString)|\(item.id)"
        _matches = Query(filter: #Predicate { $0.id == id })
    }

    private var record: DownloadEntity? { matches.first }

    var body: some View {
        Group {
            if !DownloadManager.isDownloadable(item.url) {
                // Live/HLS streams can't be saved as a file — hide the control.
                EmptyView()
            } else if let record {
                switch record.state {
                case .completed:
                    button(icon: "checkmark.circle.fill", tint: .green) { downloads.delete(record) }
                case .failed:
                    button(icon: "exclamationmark.arrow.circlepath", tint: .orange) {
                        downloads.delete(record)
                        downloads.start(item: item, profileID: profileID)
                    }
                case .downloading:
                    progressRing(downloads.progress(forDownloadID: record.id, fallback: record.progress))
                }
            } else {
                button(icon: "arrow.down.circle", tint: .primary) {
                    downloads.start(item: item, profileID: profileID)
                }
            }
        }
    }

    private func button(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.glass)
    }

    private func progressRing(_ progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(LinearGradient.brand, style: .init(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "stop.fill")
                .font(.caption2)
        }
        .frame(width: 28, height: 28)
        .padding(8)
    }
}
