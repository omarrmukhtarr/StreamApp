import SwiftUI

// MARK: - Group Filter Chips

/// Horizontal bar of liquid-glass category chips.
struct GroupChipsBar: View {
    let groups: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(groups, id: \.self) { group in
                    chip(title: group, isSelected: selection == group) {
                        selection = group
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        if isSelected {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .buttonStyle(.glassProminent)
            .tint(.brandPrimary)
        } else {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .buttonStyle(.glass)
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(LinearGradient.brand)
            }
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Channel Row

struct ChannelRow: View {
    let channel: LiveChannel
    let nowPlaying: EPGProgram?
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(url: channel.logoURL, systemFallback: "tv", contentMode: .fit)
                .frame(width: 54, height: 54)
                .padding(6)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(channel.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                if let nowPlaying {
                    Text(nowPlaying.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressBar(progress: nowPlaying.progress())
                        .frame(maxWidth: 180)
                } else {
                    Text(channel.group)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(LinearGradient.brand)
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }
}

// MARK: - Loading / Error States

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.brand)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                Task { await retry() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(.brandPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
