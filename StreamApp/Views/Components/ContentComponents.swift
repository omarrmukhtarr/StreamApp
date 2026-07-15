import SwiftUI

/// A titled horizontal rail. Replaces the repeated
/// `SectionHeader + ScrollView(.horizontal) + LazyHStack` boilerplate.
struct HScrollSection<Content: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, systemImage: systemImage)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    content()
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Poster that navigates to a movie's detail page. Reused everywhere a movie
/// appears in a rail or grid.
struct MovieCard: View {
    let movie: Movie
    var width: CGFloat = 120
    var showSubtitle = true

    var body: some View {
        NavigationLink {
            MovieDetailView(movie: movie)
        } label: {
            PosterCard(
                title: movie.title,
                imageURL: movie.posterURL,
                subtitle: showSubtitle ? (movie.year ?? movie.group) : nil,
                width: width
            )
        }
        .buttonStyle(.plain)
    }
}

/// Poster that navigates to a series' detail page.
struct SeriesCard: View {
    let series: Series
    var width: CGFloat = 120
    var showSubtitle = true

    var body: some View {
        NavigationLink {
            SeriesDetailView(series: series)
        } label: {
            PosterCard(
                title: series.title,
                imageURL: series.posterURL,
                subtitle: showSubtitle ? series.group : nil,
                width: width
            )
        }
        .buttonStyle(.plain)
    }
}

/// Round channel logo + name, used in Home rails and channel grids.
struct ChannelAvatarCard: View {
    let channel: LiveChannel
    var size: CGFloat = 64

    var body: some View {
        VStack(spacing: 8) {
            RemoteImage(url: channel.logoURL, systemFallback: "tv", contentMode: .fit)
                .frame(width: size, height: size)
                .padding(10)
                .glassEffect(.regular, in: .circle)
            Text(channel.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: size + 20)
        }
    }
}
