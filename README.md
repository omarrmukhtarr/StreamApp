# StreamApp

A modern IPTV & streaming app for iOS 26, built with SwiftUI, MVVM and Apple's Liquid Glass design system.

> 📖 Full technical documentation for every file: [DOCUMENTATION.md](DOCUMENTATION.md)

## Features

- **Demo Mode** — the app launches fully populated with sample channels, movies, series and a working TV guide (public test streams), so every screen is usable before you add a source.
- **Playlist sources** — M3U/M3U8 playlists and Xtream Codes accounts, with connection validation before saving. Manage multiple playlists and switch the active one in Settings.
- **Live TV** — channel list with category filter chips, channel logos, search, and swipe-to-favorite.
- **TV Guide (EPG)** — XMLTV guides (plain or `.gz` compressed) parsed in the background; now-playing and up-next shown in channel rows and inside the player. Xtream accounts load the guide automatically from `xmltv.php`.
- **Movies & Series (VOD)** — poster grids with category filters, detail pages (plot, cast, rating fetched on demand for Xtream), season/episode browsing.
- **Continue Watching** — playback position is saved automatically and resumable from the Home screen; items near the end are marked finished.
- **Favorites** — channels, movies and series, surfaced on Home.
- **Universal search** — across channels, movies and series from the dedicated search tab.
- **Player** — custom AVPlayer UI with liquid-glass controls: play/pause, ±10s skip, seek bar, double-tap to skip, aspect fill toggle, Picture in Picture, AirPlay, LIVE badge with EPG info, auto-hiding controls.

## Architecture (MVVM)

```
StreamApp/
├── App/            # App entry, root view, tab bar
├── Models/         # Value models, SwiftData entities, EPG models
├── Services/       # M3UParser, XtreamService, EPGService, ContentStore, PlaybackCoordinator
├── ViewModels/     # One @Observable view model per screen + PlayerViewModel
└── Views/          # SwiftUI views (Home, LiveTV, Movies, Series, Search, Settings, Player)
```

- **Services** are the data layer: parsing, networking, and the `ContentStore` single source of truth.
- **ViewModels** hold screen state and filtering/business logic (`@Observable`, `@MainActor`).
- **Views** are declarative SwiftUI using iOS 26 Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.glass`/`.glassProminent` button styles, floating tab bar with `tabBarMinimizeBehavior`).
- **Persistence** is SwiftData: playlists, favorites, watch progress.

## Building

Requires Xcode 26+. The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate   # after changing project.yml or adding files
open StreamApp.xcodeproj
```

Then build & run the `StreamApp` scheme on an iOS 26 simulator or device.

> Note: this app is a player. It does not include any content — you supply your own playlist or provider credentials.
