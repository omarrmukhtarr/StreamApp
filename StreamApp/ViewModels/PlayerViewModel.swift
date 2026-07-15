import AVFoundation
import AVKit
import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PlayerViewModel {

    /// Lightweight, view-friendly description of a subtitle or audio track.
    struct MediaOption: Identifiable, Hashable {
        let id: String
        let name: String
        let isOff: Bool
    }

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

    // Media selection (subtitles / audio)
    private(set) var subtitleOptions: [MediaOption] = []
    private(set) var audioOptions: [MediaOption] = []
    private(set) var currentSubtitleID: String = MediaOption.offID
    private(set) var currentAudioID: String?

    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private let pip = PiPCoordinator()
    private(set) var isPiPActive = false
    private var modelContext: ModelContext?
    private var profileID: UUID?
    private var hideControlsTask: Task<Void, Never>?
    private var ticksSinceSave = 0

    private var legibleGroup: AVMediaSelectionGroup?
    private var audibleGroup: AVMediaSelectionGroup?
    private var legibleOptions: [AVMediaSelectionOption] = []
    private var audibleOptions: [AVMediaSelectionOption] = []

    var isLive: Bool { item.kind == .live }
    var canSkip: Bool { !isLive && duration > 0 }
    var isPiPSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }
    var hasSubtitles: Bool { subtitleOptions.count > 1 }
    var hasMultipleAudio: Bool { audioOptions.count > 1 }

    init(item: PlayableItem) {
        self.item = item
        pip.onStart = { [weak self] in self?.isPiPActive = true }
        pip.onStop = { [weak self] in self?.isPiPActive = false }
    }

    // MARK: - Lifecycle

    func configure(context: ModelContext, profileID: UUID?) {
        self.modelContext = context
        self.profileID = profileID
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
                    await self.loadMediaOptions(for: observedItem)
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
        pip.detach()
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
        pip.attach(layer: layer)
    }

    func startPictureInPicture() {
        pip.start()
    }

    // MARK: - Media Selection (Subtitles / Audio)

    private func loadMediaOptions(for playerItem: AVPlayerItem) async {
        let asset = playerItem.asset

        if let legible = try? await asset.loadMediaSelectionGroup(for: .legible) {
            legibleGroup = legible
            legibleOptions = legible.options
            subtitleOptions = [MediaOption(id: MediaOption.offID, name: "Off", isOff: true)]
                + legible.options.enumerated().map { index, option in
                    MediaOption(id: String(index), name: option.displayName, isOff: false)
                }
            let selected = playerItem.currentMediaSelection.selectedMediaOption(in: legible)
            currentSubtitleID = selected.flatMap { legible.options.firstIndex(of: $0) }.map(String.init) ?? MediaOption.offID
        }

        if let audible = try? await asset.loadMediaSelectionGroup(for: .audible) {
            audibleGroup = audible
            audibleOptions = audible.options
            audioOptions = audible.options.enumerated().map { index, option in
                MediaOption(id: String(index), name: option.displayName, isOff: false)
            }
            let selected = playerItem.currentMediaSelection.selectedMediaOption(in: audible)
            currentAudioID = selected.flatMap { audible.options.firstIndex(of: $0) }.map(String.init)
        }
    }

    func selectSubtitle(_ option: MediaOption) {
        guard let group = legibleGroup else { return }
        if option.isOff {
            player.currentItem?.select(nil, in: group)
        } else if let index = Int(option.id), legibleOptions.indices.contains(index) {
            player.currentItem?.select(legibleOptions[index], in: group)
        }
        currentSubtitleID = option.id
        scheduleControlsHide()
    }

    func selectAudio(_ option: MediaOption) {
        guard let group = audibleGroup, let index = Int(option.id), audibleOptions.indices.contains(index) else { return }
        player.currentItem?.select(audibleOptions[index], in: group)
        currentAudioID = option.id
        scheduleControlsHide()
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
        guard let modelContext, let profileID else { return nil }
        return Library.watchProgress(for: item.id, profileID: profileID, in: modelContext)?.position
    }

    private func saveProgress() {
        guard !isLive, duration > 0, currentTime > 15, let modelContext, let profileID else { return }

        let existing = Library.watchProgress(for: item.id, profileID: profileID, in: modelContext)

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
                    contentKey: item.id,
                    profileID: profileID,
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

// MARK: - Helpers

extension PlayerViewModel.MediaOption {
    static let offID = "off"
}

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
