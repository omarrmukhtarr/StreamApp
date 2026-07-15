import AVKit
import Foundation

/// Wraps `AVPictureInPictureController` and its delegate so the player view
/// model doesn't have to be an `NSObject`. Enables automatic PiP when the
/// app is backgrounded, and reports state changes back via closures.
final class PiPCoordinator: NSObject, AVPictureInPictureControllerDelegate {
    private var controller: AVPictureInPictureController?

    var onStart: (() -> Void)?
    var onStop: (() -> Void)?

    var isPossible: Bool { controller?.isPictureInPicturePossible ?? false }

    func attach(layer: AVPlayerLayer) {
        guard controller == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        controller?.delegate = self
        self.controller = controller
    }

    func start() {
        guard let controller, controller.isPictureInPicturePossible else { return }
        controller.startPictureInPicture()
    }

    func stop() {
        controller?.stopPictureInPicture()
    }

    func detach() {
        controller?.delegate = nil
        controller = nil
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        onStart?()
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        onStop?()
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // The player is presented as a full-screen cover that stays alive during
        // PiP, so there's nothing to rebuild — just confirm restoration.
        completionHandler(true)
    }
}
