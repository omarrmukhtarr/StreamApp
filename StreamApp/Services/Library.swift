import Foundation
import SwiftData

/// Reusable, profile-scoped helpers for the user's library (favorites,
/// watch progress, downloads). Centralized here so no view re-implements
/// the fetch/toggle logic.
enum Library {

    // MARK: - Favorites

    static func isFavorite(_ contentKey: String, profileID: UUID, in context: ModelContext) -> Bool {
        let id = compositeID(profileID, contentKey)
        let descriptor = FetchDescriptor<FavoriteEntity>(predicate: #Predicate { $0.id == id })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Adds or removes a favorite for the current profile. Returns the new state.
    @discardableResult
    static func toggleFavorite(
        contentKey: String,
        kind: ContentKind,
        profileID: UUID,
        in context: ModelContext
    ) -> Bool {
        let id = compositeID(profileID, contentKey)
        let descriptor = FetchDescriptor<FavoriteEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
            return false
        }
        context.insert(FavoriteEntity(contentKey: contentKey, kind: kind, profileID: profileID))
        try? context.save()
        return true
    }

    // MARK: - Watch Progress

    static func watchProgress(
        for contentKey: String,
        profileID: UUID,
        in context: ModelContext
    ) -> WatchProgressEntity? {
        let id = compositeID(profileID, contentKey)
        let descriptor = FetchDescriptor<WatchProgressEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    // MARK: - Downloads

    static func download(
        for contentKey: String,
        profileID: UUID,
        in context: ModelContext
    ) -> DownloadEntity? {
        let id = compositeID(profileID, contentKey)
        let descriptor = FetchDescriptor<DownloadEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    // MARK: - Helpers

    static func compositeID(_ profileID: UUID, _ contentKey: String) -> String {
        "\(profileID.uuidString)|\(contentKey)"
    }
}
