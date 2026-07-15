import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }
            Tab("Live TV", systemImage: "tv") {
                LiveTVView()
            }
            Tab("Movies", systemImage: "film.stack") {
                MoviesView()
            }
            Tab("Series", systemImage: "rectangle.stack.badge.play") {
                SeriesView()
            }
            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
