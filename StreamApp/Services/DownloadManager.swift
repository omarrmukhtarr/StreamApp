import Foundation
import Observation
import SwiftData

/// Downloads progressive video files (mp4/mkv/…) for offline playback and
/// keeps their `DownloadEntity` records in sync. Progressive files are used
/// because typical VOD streams are direct files; HLS (`.m3u8`) is rejected
/// up front since it needs a different (asset-bundle) download path.
@MainActor
@Observable
final class DownloadManager: NSObject {

    /// Live progress keyed by composite download id, for smooth UI updates
    /// without hammering SwiftData on every callback.
    private(set) var progressByID: [String: Double] = [:]

    private var container: ModelContainer?
    private var session: URLSession!
    /// Maps a URLSession task id → the download's composite id.
    private var taskToDownloadID: [Int: String] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func configure(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Directory

    nonisolated static var downloadsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Public API

    static func isDownloadable(_ url: URL) -> Bool {
        url.pathExtension.lowercased() != "m3u8"
    }

    /// Begins downloading `item` for `profileID`. No-op if already present.
    func start(item: PlayableItem, profileID: UUID) {
        guard let context = container?.mainContext, Self.isDownloadable(item.url) else { return }
        let id = Library.compositeID(profileID, item.id)
        if Library.download(for: item.id, profileID: profileID, in: context) != nil { return }

        let entity = DownloadEntity(
            contentKey: item.id,
            profileID: profileID,
            title: item.title,
            subtitle: item.subtitle,
            artworkURLString: item.artworkURL?.absoluteString,
            remoteURLString: item.url.absoluteString
        )
        context.insert(entity)
        try? context.save()

        let task = session.downloadTask(with: item.url)
        taskToDownloadID[task.taskIdentifier] = id
        progressByID[id] = 0
        task.resume()
    }

    /// Deletes a download's record and its file from disk.
    func delete(_ download: DownloadEntity) {
        guard let context = container?.mainContext else { return }
        if let localURL = download.localURL {
            try? FileManager.default.removeItem(at: localURL)
        }
        progressByID[download.id] = nil
        context.delete(download)
        try? context.save()
    }

    func progress(forDownloadID id: String, fallback: Double) -> Double {
        progressByID[id] ?? fallback
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let id = self.taskToDownloadID[taskID] else { return }
            self.progressByID[id] = fraction
            // Persist coarse progress occasionally so it survives relaunch.
            if let entity = self.entity(withID: id), abs(entity.progress - fraction) > 0.05 {
                entity.progress = fraction
                try? self.container?.mainContext.save()
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let taskID = downloadTask.taskIdentifier
        // Move the file synchronously here (the temp file is deleted after return).
        let ext = downloadTask.originalRequest?.url?.pathExtension ?? "mp4"
        let fileName = "\(UUID().uuidString).\(ext.isEmpty ? "mp4" : ext)"
        let destination = Self.downloadsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.moveItem(at: location, to: destination)

        Task { @MainActor in
            guard let id = self.taskToDownloadID[taskID], let entity = self.entity(withID: id) else { return }
            entity.localFileName = fileName
            entity.progress = 1
            entity.state = .completed
            self.progressByID[id] = 1
            self.taskToDownloadID[taskID] = nil
            try? self.container?.mainContext.save()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let taskID = task.taskIdentifier
        Task { @MainActor in
            guard let id = self.taskToDownloadID[taskID], let entity = self.entity(withID: id) else { return }
            entity.state = .failed
            self.progressByID[id] = nil
            self.taskToDownloadID[taskID] = nil
            try? self.container?.mainContext.save()
            _ = error
        }
    }

    private func entity(withID id: String) -> DownloadEntity? {
        guard let context = container?.mainContext else { return nil }
        let descriptor = FetchDescriptor<DownloadEntity>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
