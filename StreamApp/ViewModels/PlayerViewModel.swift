import AVFoundation
import AVKit
import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PlayerViewModel {

    let item: PlayableItem
    let player = AVPlayer()

    private(set) var isPlaying = false
    private(set) var isBuffering = true
    private(set) var duration: Double = 0
    private(set) var failureMessage: String?
    var currentTime: Double = 0
    var isSeeking = false
    var controlsVisible = true
    var isAspectFill = false

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var pipController: AVPictureInPictureController?
    private var modelContext: ModelContext?
    private var hideControlsTask: Task<Void, Never>?
    private var ticksSinceSave = 0

    var isLive: Bool { item.kind == .live }
    var canSkip: Bool { !isLive && duration > 0 }
    var isPiPSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    init(item: PlayableItem) {
        self.item = item
    }

    // MARK: - Lifecycle

    func configure(context: ModelContext) {
        modelContext = context
    }

    func start() {
        let playerItem = AVPlayerItem(url: item.url)
        player.replaceCurrentItem(with: playerItem)
        player.allowsExternalPlayback = true

        itemStatusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    let seconds = observedItem.duration.seconds
                    self.duration = seconds.isFinite ? seconds : 0
                case .failed:
                    self.failureMessage = "This stream could not be played. It may be offline or in an unsupported format."
                    self.isBuffering = false
                default:
                    break
                }
            }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observedPlayer, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = observedPlayer.timeControlStatus == .playing
                self.isBuffering = observedPlayer.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.tick(time: time)
            }
        }

        if !isLive, let resume = savedPosition(), resume > 15 {
            player.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }

        player.play()
        UIApplication.shared.isIdleTimerDisabled = true
        scheduleControlsHide()
    }

    func stop() {
        saveProgress()
        hideControlsTask?.cancel()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        statusObservation = nil
        itemStatusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Controls

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        scheduleControlsHide()
    }

    func skip(by seconds: Double) {
        guard canSkip else { return }
        let target = min(max(0, currentTime + seconds), duration)
        seek(to: target)
        scheduleControlsHide()
    }

    func seek(to seconds: Double) {
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func toggleControls() {
        withAnimation { controlsVisible.toggle() }
        if controlsVisible {
            scheduleControlsHide()
        }
    }

    func scheduleControlsHide() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled, self.isPlaying, !self.isSeeking else { return }
            withAnimation { self.controlsVisible = false }
        }
    }

    // MARK: - Picture in Picture

    func attach(layer: AVPlayerLayer) {
        guard pipController == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        pipController = AVPictureInPictureController(playerLayer: layer)
    }

    func startPictureInPicture() {
        pipController?.startPictureInPicture()
    }

    // MARK: - Watch Progress

    private func tick(time: CMTime) {
        if !isSeeking {
            let seconds = time.seconds
            currentTime = seconds.isFinite ? seconds : 0
        }
        ticksSinceSave += 1
        if ticksSinceSave >= 20 { // every ~10 seconds
            ticksSinceSave = 0
            saveProgress()
        }
    }

    private func savedPosition() -> Double? {
        guard let modelContext else { return nil }
        let key = item.id
        let descriptor = FetchDescriptor<WatchProgressEntity>(
            predicate: #Predicate { $0.key == key }
        )
        return try? modelContext.fetch(descriptor).first?.position
    }

    private func saveProgress() {
        guard !isLive, duration > 0, currentTime > 15, let modelContext else { return }

        let key = item.id
        let descriptor = FetchDescriptor<WatchProgressEntity>(
            predicate: #Predicate { $0.key == key }
        )
        let existing = try? modelContext.fetch(descriptor).first

        // Consider it finished near the end and clear it from Continue Watching.
        if currentTime > duration * 0.95 {
            if let existing {
                modelContext.delete(existing)
                try? modelContext.save()
            }
            return
        }

        if let existing {
            existing.position = currentTime
            existing.duration = duration
            existing.updatedAt = .now
        } else {
            modelContext.insert(
                WatchProgressEntity(
                    key: key,
                    kind: item.kind,
                    title: item.title,
                    subtitle: item.subtitle,
                    artworkURLString: item.artworkURL?.absoluteString,
                    streamURLString: item.url.absoluteString,
                    position: currentTime,
                    duration: duration
                )
            )
        }
        try? modelContext.save()
    }
}

// MARK: - Time Formatting

extension PlayerViewModel {
    static func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
