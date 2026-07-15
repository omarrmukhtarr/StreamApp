import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AddPlaylistViewModel {

    var kind: PlaylistKind = .m3u
    var name = ""
    var urlString = ""
    var username = ""
    var password = ""
    var epgURLString = ""

    private(set) var isValidating = false
    var errorMessage: String?

    var canSubmit: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              !urlString.trimmingCharacters(in: .whitespaces).isEmpty
        else { return false }
        if kind == .xtream {
            return !username.isEmpty && !password.isEmpty
        }
        return true
    }

    /// Validates the source against the server, then saves and activates it.
    /// Returns true on success.
    func validateAndSave(context: ModelContext) async -> Bool {
        errorMessage = nil
        isValidating = true
        defer { isValidating = false }

        guard let url = normalizedURL() else {
            errorMessage = "Please enter a valid URL (e.g. http://example.com:8080)."
            return false
        }

        do {
            switch kind {
            case .m3u:
                try await validateM3U(url: url)
            case .xtream:
                let service = XtreamService(baseURL: url, username: username, password: password)
                try await service.authenticate()
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Could not connect. Check the details and try again."
            return false
        }

        let entity = PlaylistEntity(
            name: name.trimmingCharacters(in: .whitespaces),
            kind: kind,
            urlString: url.absoluteString,
            username: kind == .xtream ? username : "",
            password: kind == .xtream ? password : "",
            epgURLString: epgURLString.isEmpty ? nil : epgURLString,
            isActive: true
        )

        // Only one playlist may be active at a time.
        let descriptor = FetchDescriptor<PlaylistEntity>()
        if let existing = try? context.fetch(descriptor) {
            for playlist in existing {
                playlist.isActive = false
            }
        }
        context.insert(entity)
        try? context.save()
        return true
    }

    private func validateM3U(url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        let prefix = String(decoding: data.prefix(1024), as: UTF8.self)
        guard prefix.contains("#EXTM3U") || prefix.contains("#EXTINF") else {
            throw AddPlaylistError.notAPlaylist
        }
    }

    private func normalizedURL() -> URL? {
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "http://" + raw
        }
        guard let url = URL(string: raw), url.host() != nil else { return nil }
        return url
    }
}

enum AddPlaylistError: LocalizedError {
    case notAPlaylist

    var errorDescription: String? {
        switch self {
        case .notAPlaylist: "The URL did not return an M3U playlist."
        }
    }
}
