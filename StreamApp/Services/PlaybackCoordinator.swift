import Foundation
import Observation

/// App-wide entry point for starting playback from any screen.
@MainActor
@Observable
final class PlaybackCoordinator {
    var current: PlayableItem?

    func play(_ item: PlayableItem) {
        current = item
    }
}
