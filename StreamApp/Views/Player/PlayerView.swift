import SwiftUI

/// Fullscreen video player with auto-hiding liquid-glass controls,
/// gestures, Picture in Picture, AirPlay and live EPG info.
struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ContentStore.self) private var store
    @Environment(ProfileStore.self) private var profiles

    @State private var model: PlayerViewModel

    init(item: PlayableItem) {
        _model = State(initialValue: PlayerViewModel(item: item))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PlayerLayerView(
                player: model.player,
                isAspectFill: model.isAspectFill,
                onLayerReady: { model.attach(layer: $0) }
            )
            .ignoresSafeArea()

            gestureLayer

            if model.isBuffering, model.failureMessage == nil {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if let failure = model.failureMessage {
                failureView(failure)
            }

            if model.controlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .statusBarHidden(!model.controlsVisible)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            model.configure(context: modelContext, profileID: profiles.currentID)
            model.start()
        }
        .onDisappear {
            model.stop()
        }
    }

    // MARK: - Gestures

    private var gestureLayer: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(count: 2) { model.skip(by: -10) }
            Color.clear
                .contentShape(.rect)
                .onTapGesture(count: 2) { model.skip(by: 10) }
        }
        .ignoresSafeArea()
        .onTapGesture { withAnimation { model.toggleControls() } }
    }

    // MARK: - Controls

    private var controlsOverlay: some View {
        VStack {
            topBar
            Spacer()
            centerControls
            Spacer()
            bottomBar
        }
        .padding()
        .background(alignment: .top) { shade(startsFromTop: true) }
        .background(alignment: .bottom) { shade(startsFromTop: false) }
    }

    private func shade(startsFromTop: Bool) -> some View {
        LinearGradient(
            colors: [.black.opacity(0.55), .clear],
            startPoint: startsFromTop ? .top : .bottom,
            endPoint: startsFromTop ? .center : .center
        )
        .frame(height: 220)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)

                Spacer()

                if model.hasSubtitles || model.hasMultipleAudio {
                    mediaSelectionMenu
                }

                AirPlayButton()
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)

                if model.isPiPSupported {
                    Button {
                        model.startPictureInPicture()
                    } label: {
                        Image(systemName: "pip.enter")
                            .font(.headline)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                }

                Button {
                    model.isAspectFill.toggle()
                } label: {
                    Image(
                        systemName: model.isAspectFill
                            ? "arrow.down.right.and.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right"
                    )
                    .font(.headline)
                    .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var subtitleText: String? {
        if model.isLive, let program = store.epg.current(for: model.item.epgChannelID) {
            return "Now: \(program.title)"
        }
        return model.item.subtitle
    }

    private var mediaSelectionMenu: some View {
        Menu {
            if model.hasSubtitles {
                Picker("Subtitles", selection: subtitleBinding) {
                    ForEach(model.subtitleOptions) { option in
                        Text(option.name).tag(option.id)
                    }
                }
            }
            if model.hasMultipleAudio {
                Picker("Audio", selection: audioBinding) {
                    ForEach(model.audioOptions) { option in
                        Text(option.name).tag(Optional(option.id))
                    }
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
                .font(.headline)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.glass)
    }

    private var subtitleBinding: Binding<String> {
        Binding(
            get: { model.currentSubtitleID },
            set: { id in
                if let option = model.subtitleOptions.first(where: { $0.id == id }) {
                    model.selectSubtitle(option)
                }
            }
        )
    }

    private var audioBinding: Binding<String?> {
        Binding(
            get: { model.currentAudioID },
            set: { id in
                if let id, let option = model.audioOptions.first(where: { $0.id == id }) {
                    model.selectAudio(option)
                }
            }
        )
    }

    private var centerControls: some View {
        GlassEffectContainer(spacing: 40) {
            HStack(spacing: 40) {
                if model.canSkip {
                    Button {
                        model.skip(by: -10)
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                }

                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34))
                        .frame(width: 62, height: 62)
                }
                .buttonStyle(.glass)

                if model.canSkip {
                    Button {
                        model.skip(by: 10)
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        @Bindable var model = model

        if model.isLive {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)

                if let next = store.epg.next(for: model.item.epgChannelID) {
                    Text("Next: \(next.title) · \(next.timeRangeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                }

                Spacer()
            }
        } else {
            VStack(spacing: 6) {
                Slider(
                    value: $model.currentTime,
                    in: 0...max(model.duration, 1),
                    onEditingChanged: { editing in
                        model.isSeeking = editing
                        if !editing {
                            model.seek(to: model.currentTime)
                            model.scheduleControlsHide()
                        }
                    }
                )
                .tint(.white)

                HStack {
                    Text(PlayerViewModel.timeString(model.currentTime))
                    Spacer()
                    Text(PlayerViewModel.timeString(model.duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }

    // MARK: - Failure

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "play.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.7))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(.brandPrimary)
        }
    }
}
