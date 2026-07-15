import Foundation
import Observation
import SwiftData

/// Tracks which profile is active. The selection is persisted in
/// `UserDefaults` so the app reopens into the last-used profile.
@MainActor
@Observable
final class ProfileStore {
    private static let defaultsKey = "currentProfileID"

    private(set) var currentID: UUID?

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.defaultsKey) {
            currentID = UUID(uuidString: stored)
        }
    }

    var hasSelection: Bool { currentID != nil }

    func select(_ profile: ProfileEntity) {
        currentID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: Self.defaultsKey)
    }

    func selectID(_ id: UUID) {
        currentID = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.defaultsKey)
    }

    func clearSelection() {
        currentID = nil
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }

    /// Ensures at least one profile exists and a valid one is selected.
    /// Returns the resolved current profile id.
    @discardableResult
    func bootstrap(context: ModelContext) -> UUID? {
        let profiles = (try? context.fetch(FetchDescriptor<ProfileEntity>())) ?? []

        if profiles.isEmpty {
            let profile = ProfileEntity(name: "Me", symbol: "person.fill", colorIndex: 0)
            context.insert(profile)
            try? context.save()
            select(profile)
            return profile.id
        }

        if let currentID, profiles.contains(where: { $0.id == currentID }) {
            return currentID
        }

        // Stored selection is missing/invalid — fall back to the first profile.
        if let first = profiles.first {
            select(first)
            return first.id
        }
        return nil
    }
}
