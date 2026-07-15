import SwiftUI

/// Poster-style card used for movies and series in grids and rows.
struct PosterCard: View {
    let title: String
    let imageURL: URL?
    var subtitle: String?
    var progress: Double?
    var width: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(url: imageURL, systemFallback: "film")
                .frame(width: width, height: width * 1.5)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(alignment: .bottom) {
                    if let progress, progress > 0 {
                        ProgressBar(progress: progress)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }

            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

/// Thin rounded progress indicator overlaid on artwork.
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.3))
                Capsule()
                    .fill(LinearGradient.brand)
                    .frame(width: max(4, geometry.size.width * progress))
            }
        }
        .frame(height: 4)
    }
}

/// Async image with a graceful glass placeholder.
struct RemoteImage: View {
    let url: URL?
    var systemFallback: String = "photo"
    var contentMode: ContentMode = .fill

    var body: some View {
        Color.clear
            .overlay {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    default:
                        ZStack {
                            LinearGradient(
                                colors: [.white.opacity(0.08), .white.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            Image(systemName: systemFallback)
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                }
            }
            .clipped()
    }
}
