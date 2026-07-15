import AVFoundation
import AVKit
import SwiftUI

/// Hosts the AVPlayerLayer so the player can render video and drive PiP.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let isAspectFill: Bool
    let onLayerReady: (AVPlayerLayer) -> Void

    func makeUIView(context: Context) -> PlayerContainerUIView {
        let view = PlayerContainerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = isAspectFill ? .resizeAspectFill : .resizeAspect
        let layer = view.playerLayer
        DispatchQueue.main.async {
            onLayerReady(layer)
        }
        return view
    }

    func updateUIView(_ uiView: PlayerContainerUIView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = isAspectFill ? .resizeAspectFill : .resizeAspect
    }
}

final class PlayerContainerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

/// System AirPlay route picker wrapped for SwiftUI.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .white
        view.activeTintColor = UIColor(Color.brandSecondary)
        view.prioritizesVideoDevices = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
