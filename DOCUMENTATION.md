# StreamApp — Complete Technical Documentation

StreamApp is an IPTV and streaming client for iOS 26, written entirely in SwiftUI using the MVVM pattern and Apple's Liquid Glass design system. This document explains the architecture, every file in the project, how data flows through the app, and how to extend it.

---

## Table of Contents

1. [What the App Does](#1-what-the-app-does)
2. [Requirements & Tooling](#2-requirements--tooling)
3. [Architecture Overview (MVVM)](#3-architecture-overview-mvvm)
4. [Project Structure](#4-project-structure)
5. [File-by-File Explanation](#5-file-by-file-explanation)
   - [Root files](#51-root-files)
   - [App/](#52-app)
   - [Models/](#53-models)
   - [Services/](#54-services)
   - [ViewModels/](#55-viewmodels)
   - [Views/](#56-views)
6. [How Data Flows](#6-how-data-flows)
7. [The Content Identity Scheme](#7-the-content-identity-scheme)
8. [Persistence (SwiftData)](#8-persistence-swiftdata)
9. [Demo Mode](#9-demo-mode)
10. [Liquid Glass Usage](#10-liquid-glass-usage)
11. [Building, Running & Regenerating the Project](#11-building-running--regenerating-the-project)
12. [How to Extend the App](#12-how-to-extend-the-app)

---

## 1. What the App Does

StreamApp plays content from two kinds of IPTV sources:

- **M3U / M3U8 playlists** — a URL that returns a text playlist of streams. The app parses it and automatically classifies each entry as a live channel, a movie, or a series episode.
- **Xtream Codes accounts** — a server + username + password. The app talks to the standard `player_api.php` API to fetch categorized live channels, movies (VOD), and series.

On top of those sources it provides: a TV guide (EPG) from XMLTV feeds, favorites, resumable "Continue Watching", universal search, and a custom full-screen video player with Picture in Picture and AirPlay.

Until the user adds a playlist, the app runs in **Demo Mode** with built-in sample content (see [section 9](#9-demo-mode)).

> The app contains no content of its own — it is a player for sources the user supplies.

## 2. Requirements & Tooling

| Requirement | Version |
|---|---|
| Xcode | 26+ |
| iOS deployment target | 26.0 |
| Swift | 5.10 |
| Project generator | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) |
| Third-party libraries | **None** — 100% Apple frameworks (SwiftUI, SwiftData, AVKit, AVFoundation, Observation, Compression) |

## 3. Architecture Overview (MVVM)

The app follows MVVM with an additional thin **Services** layer (sometimes called MVVM-S). Dependencies point in one direction only:

```
┌─────────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                            │
│  HomeView, LiveTVView, MoviesView, SeriesView, SearchView,  │
│  SettingsView, AddPlaylistView, PlayerView, components      │
└───────────────▲─────────────────────────────────────────────┘
                │ observe state / call methods
┌───────────────┴─────────────────────────────────────────────┐
│  ViewModels (@Observable, @MainActor)                        │
│  LiveTVViewModel, MoviesViewModel, SeriesViewModel,          │
│  SeriesDetailViewModel, SearchViewModel, PlayerViewModel,    │
│  AddPlaylistViewModel                                        │
└───────────────▲─────────────────────────────────────────────┘
                │ use
┌───────────────┴─────────────────────────────────────────────┐
│  Services                                                    │
│  ContentStore (single source of truth), M3UParser,           │
│  XtreamService, EPGService, MockDataService,                 │
│  PlaybackCoordinator                                         │
└───────────────▲─────────────────────────────────────────────┘
                │ produce / consume
┌───────────────┴─────────────────────────────────────────────┐
│  Models                                                      │
│  Value types: LiveChannel, Movie, Series, Episode,           │
│               PlayableItem, EPGProgram, EPGSnapshot          │
│  SwiftData:   PlaylistEntity, FavoriteEntity,                │
│               WatchProgressEntity                            │
└──────────────────────────────────────────────────────────────┘
```

Key decisions:

- **`ContentStore` is the single source of truth** for the active playlist's content. Every screen reads channels/movies/series/EPG from it via the SwiftUI environment. It is `@MainActor @Observable`, so views update automatically when it changes.
- **ViewModels own screen state** (selected category, search text, player state) and pure logic (filtering). They never touch SwiftUI views.
- **Models are dumb data.** Value structs for content (safe to pass across concurrency domains), SwiftData `@Model` classes only for what must persist.
- **Views are declarative and thin.** They render state and forward user intent to view models / services.

## 4. Project Structure

```
StreamApp/
├── project.yml                    # XcodeGen project definition (the .xcodeproj is generated)
├── README.md                      # Quick start
├── DOCUMENTATION.md               # This file
├── StreamApp.xcodeproj            # GENERATED — never edit by hand
└── StreamApp/                     # All source code
    ├── Info.plist                 # GENERATED by XcodeGen from project.yml
    ├── App/
    │   ├── StreamAppApp.swift     # @main entry point
    │   ├── RootView.swift         # Playlist activation + player presentation
    │   └── MainTabView.swift      # Liquid Glass tab bar
    ├── Models/
    │   ├── Content.swift          # LiveChannel, Movie, Series, Episode, PlayableItem
    │   ├── EPG.swift              # EPGProgram, EPGSnapshot
    │   └── PersistenceModels.swift# SwiftData entities + PlaylistConfig
    ├── Services/
    │   ├── ContentStore.swift     # Single source of truth for content
    │   ├── M3UParser.swift        # M3U/M3U8 text parser + classifier
    │   ├── XtreamService.swift    # Xtream Codes API client + DTOs
    │   ├── EPGService.swift       # XMLTV downloader/parser (+ gzip)
    │   ├── MockDataService.swift  # Demo-mode sample content
    │   └── PlaybackCoordinator.swift # App-wide "play this" entry point
    ├── ViewModels/
    │   ├── LiveTVViewModel.swift
    │   ├── MoviesViewModel.swift
    │   ├── SeriesViewModel.swift  # + SeriesDetailViewModel
    │   ├── SearchViewModel.swift
    │   ├── PlayerViewModel.swift
    │   └── AddPlaylistViewModel.swift
    └── Views/
        ├── Theme.swift            # Colors, gradients, app background
        ├── Components/
        │   ├── PosterCard.swift   # PosterCard, ProgressBar, RemoteImage
        │   └── SharedComponents.swift # Chips bar, section header, channel row, states
        ├── Home/HomeView.swift
        ├── LiveTV/LiveTVView.swift
        ├── Movies/MoviesView.swift, MovieDetailView.swift
        ├── Series/SeriesView.swift, SeriesDetailView.swift
        ├── Search/SearchView.swift
        ├── Settings/SettingsView.swift, AddPlaylistView.swift
        └── Player/PlayerView.swift, PlayerSupport.swift
```

---

## 5. File-by-File Explanation

### 5.1 Root files

#### `project.yml`
The XcodeGen definition of the Xcode project. Declares the single iOS app target, deployment target (iOS 26), bundle id (`com.omermukhtar.streamapp`), and the generated `Info.plist` contents:

- `UIBackgroundModes: [audio]` — keeps audio playing (and enables PiP) when the app is backgrounded.
- `NSAppTransportSecurity → NSAllowsArbitraryLoads: true` — IPTV servers are very often plain `http://`; this permits those connections.
- Supported orientations for iPhone and iPad (the player rotates to landscape).

Whenever you add/remove Swift files or change this file, run `xcodegen generate` to rebuild `StreamApp.xcodeproj`.

---

### 5.2 App/

#### `App/StreamAppApp.swift`
The `@main` entry point. Responsibilities:

1. **Creates the SwiftData `ModelContainer`** for the three persisted entities (playlists, favorites, watch progress). A failure here is unrecoverable, hence `fatalError`.
2. **Creates the two app-wide observable objects** — `ContentStore` (content) and `PlaybackCoordinator` (playback requests) — and injects them into the environment so any view can reach them.
3. **Configures a large `URLCache`** (64 MB memory / 512 MB disk) so channel logos and posters loaded through `AsyncImage` are cached instead of re-downloaded.
4. **Sets the AVAudioSession category** to `.playback` so video audio behaves like a media app (plays over the silent switch, supports background audio).
5. Forces dark mode (`.preferredColorScheme(.dark)`) — the cinematic look the UI is designed around — and sets the global accent tint.

#### `App/RootView.swift`
Sits directly inside the `WindowGroup` and does two jobs:

- **Playlist activation.** A `@Query` observes all `PlaylistEntity` rows. The `.task(id: activePlaylistID)` modifier re-runs whenever the *active* playlist changes (added, switched, deleted) and tells `ContentStore.activateIfNeeded(_:)` to load it. If there is no playlist at all, the store falls back to demo content. This is the *only* place where SwiftData playlists are converted into a `PlaylistConfig` and handed to the service layer.
- **Player presentation.** Binds `PlaybackCoordinator.current` to a `fullScreenCover`. Any screen can call `playback.play(item)` and the player appears on top of everything; dismissing the cover sets `current` back to `nil`.

#### `App/MainTabView.swift`
The five-tab root UI using the modern `Tab` API:
Home, Live TV, Movies, Series, and Search (declared with `role: .search`, which gives it the system search appearance and placement). `.tabBarMinimizeBehavior(.onScrollDown)` enables the iOS 26 floating Liquid Glass tab bar that shrinks away while scrolling content.

---

### 5.3 Models/

#### `Models/Content.swift`
The value types that represent playable content. All are `Identifiable`, `Hashable`, `Codable` structs — cheap to copy, safe to send between tasks.

- **`LiveChannel`** — id, optional channel `number`, name, logo URL, stream URL, `group` (category), and `epgChannelID` (the XMLTV `tvg-id` used to match guide data).
- **`Movie`** — id, title, poster, stream URL, group, plus optional metadata (`year`, `rating`, `addedAt` for "Recently Added" sorting, and `plot`/`genre`/`cast`/`durationText` which are `var` because Xtream fills them lazily on the detail screen). `vodID` stores the raw Xtream id needed for that lazy fetch.
- **`Series`** — id, title, poster, group, optional plot/rating/release date. `seriesID` is the raw Xtream id used to fetch episodes on demand (nil for M3U-derived series, whose episodes are already known).
- **`Episode`** — id, title, `season`, `episodeNumber`, stream URL, optional plot/duration/image.
- **`PlayableItem`** — the *normalized* thing the player consumes: id, `Kind` (`.live`/`.movie`/`.episode`), title, subtitle, artwork, URL, and EPG channel id. The extensions at the bottom (`LiveChannel.playable`, `Movie.playable`, `Episode.playable(in:)`) convert any content type into a `PlayableItem`, so the player never needs to know where content came from.

#### `Models/EPG.swift`
TV-guide models.

- **`EPGProgram`** — one program: channel id, title, description, start/end dates. Helpers: `timeRangeText` (formatted "20:00 – 20:45") and `progress(at:)` (0…1 fraction of how far the program has aired — drives the little progress bars in channel rows).
- **`EPGSnapshot`** — an immutable dictionary of programs keyed by **lowercased** XMLTV channel id, plus `updatedAt`. Lookup helpers: `current(for:)` (what's on now), `next(for:)` (what's next), `programs(for:)`, and `programCount` (shown in Settings). Keeping it a value snapshot means the UI can never observe a half-updated guide.

#### `Models/PersistenceModels.swift`
Everything related to persistence and source configuration.

- **`PlaylistKind`** — `.m3u` or `.xtream`, with display names for the UI.
- **`ContentKind`** — `.live`/`.movie`/`.series`, used to tag favorites.
- **`PlaylistEntity`** (SwiftData `@Model`) — a saved source: name, kind, URL string, credentials (Xtream), optional EPG URL override (M3U), `isActive` flag (only one playlist is active at a time), creation date.
- **`FavoriteEntity`** (`@Model`) — deliberately tiny: just the content `key`, its kind, and when it was added. Favorites are *resolved* against the loaded content at display time (`ContentStore.channel(forKey:)` etc.), so nothing stale is stored and favorites survive playlist refreshes.
- **`WatchProgressEntity`** (`@Model`) — resume data: key, kind, title, subtitle, artwork URL, **stream URL**, position, duration, updated date. It intentionally stores enough to rebuild a `PlayableItem` (`.playable` computed property) so "Continue Watching" can start playback even before/without the playlist being loaded.
- **`PlaylistConfig`** — an immutable **value copy** of a `PlaylistEntity`. SwiftData model objects are not safe to pass around threads/tasks freely; the config struct is. Its failable initializer also validates the URL once, up front.

---

### 5.4 Services/

#### `Services/ContentStore.swift`
The heart of the app — a `@MainActor @Observable` class holding all content for the active source.

State it exposes:

- `state`: `.idle` / `.loading` / `.loaded` / `.failed(message)` — every list screen switches on this.
- `channels`, `movies`, `series` — the loaded content.
- `epg` — the current `EPGSnapshot`; `isLoadingEPG` for the Settings spinner.
- `activeConfig` — which playlist is loaded; `isDemo` — whether sample content is showing.
- Derived: `channelGroups` / `movieGroups` / `seriesGroups` (unique category names in original order) and `recentMovies` (sorted by `addedAt` when available).

What it does:

- **`activateIfNeeded(config:)`** — called by `RootView`. Loads the given playlist if it isn't already loaded; with `nil` it activates demo content instead.
- **`loadM3U`** — downloads the playlist text (UTF-8 with Latin-1 fallback), parses it with `M3UParser` on a detached background task, then stores the result. If the playlist (or the playlist entity) referenced an XMLTV URL, kicks off a background EPG load.
- **`loadXtream`** — fires six requests **in parallel** (`async let`): live/VOD/series categories + streams. Maps category ids to names, builds streaming URLs via `XtreamService`, and converts DTOs into the app's value models. EPG loads in the background from the server's `xmltv.php`.
- **`episodes(for:)`** — season→episodes dictionary. For Xtream it fetches `get_series_info` on demand; for M3U (and demo) it returns the episodes collected at parse time.
- **`loadEPGInBackground`** — cancellable background task; the snapshot is only applied if the same playlist is still active (guards against switching playlists mid-download).
- **Race safety** — every loader re-checks `activeConfig == config` before writing results, so a stale load can never overwrite a newer one.
- **Hygiene** — results are deduplicated by id (broken playlists often repeat entries; duplicate ids would break `ForEach`), and lookup dictionaries (`channelsByID`…) are rebuilt for O(1) favorite resolution.
- **`friendlyMessage(for:)`** — converts network errors into human-readable text for the error screens.

#### `Services/M3UParser.swift`
A dependency-free parser for the (very messy, very unstandardized) M3U format.

- Reads line pairs: `#EXTINF:-1 key="value" …,Display Name` followed by the stream URL. Attributes (`tvg-id`, `tvg-logo`, `group-title`, …) are extracted with a small hand-written scanner (`parseAttributes`) rather than a regex, which tolerates malformed lines. The display title is everything after the **last comma outside of quotes** (`lastCommaOutsideQuotes`) — commas inside quoted attribute values must not split the title.
- Reads the header `#EXTM3U url-tvg="…"` (or `x-tvg-url`) to discover the playlist's EPG feed, and supports `#EXTGRP:` group lines.
- **Classifies every entry** with heuristics used by major IPTV apps:
  1. If the name matches `S01E02`-style patterns (regex `S(\d{1,2})…E(\d{1,4})`, tolerant of separators) → it's a **series episode**; the text before the pattern becomes the series title, and episodes are grouped per series.
  2. Else if the URL's file extension is a movie container (`mp4`, `mkv`, `avi`, …) → **movie**. (`ts`/`m3u8` are deliberately *not* in the list — those are live formats.)
  3. Otherwise → **live channel**.
- Returns an `M3UParseResult` (channels, movies, series, episodes-by-series, EPG URL).

#### `Services/XtreamService.swift`
The Xtream Codes API client plus all its DTOs. Split into four parts:

1. **Endpoints** — `authenticate()` (used by the Add Playlist form to validate credentials), `fetchLiveCategories/Streams`, `fetchVODCategories/Streams`, `fetchSeriesCategories`, `fetchSeries`, `fetchSeriesInfo(seriesID:)`, `fetchVODInfo(vodID:)`, `fetchShortEPG(streamID:)`. All go through one private `fetch(action:extra:)` that builds the `player_api.php` query safely with `URLComponents`.
2. **Stream URL builders** — Xtream stream URLs follow fixed patterns which the API does not return directly:
   - live: `{base}/live/{user}/{pass}/{stream_id}.m3u8`
   - movie: `{base}/movie/{user}/{pass}/{id}.{container_extension}`
   - episode: `{base}/series/{user}/{pass}/{episode_id}.{ext}`
   - full XMLTV guide: `{base}/xmltv.php?username=…&password=…`
3. **`FlexString`** — the single most important type for real-world compatibility. Xtream panels are wildly inconsistent about JSON types (`stream_id` may be a number *or* a string; `rating` may be `"7.2"`, `7.2`, or `null`). `FlexString` decodes *any* scalar into a string, with `intValue`/`doubleValue` accessors. Every potentially-numeric DTO field uses it.
4. **DTOs** — `XtreamCategory`, `XtreamLiveStream`, `XtreamVODStream`, `XtreamSeriesItem`, `XtreamEpisode`, `XtreamSeriesInfo`, `XtreamVODInfo`, `XtreamEPGResponse`. Two defensive-decoding highlights:
   - `XtreamEpisode.info` is sometimes an object and sometimes an empty array — the custom `init(from:)` tries the object and falls back to nils.
   - `XtreamSeriesInfo.episodes` is sometimes `{"1": […]}` and sometimes `[[…]]` — both shapes are handled.
   - Short-EPG titles/descriptions arrive base64-encoded and are decoded transparently.

#### `Services/EPGService.swift`
Downloads and parses XMLTV TV guides.

- **Gzip support**: many providers serve `guide.xml.gz`. Foundation has no gzip API, so the service detects the magic bytes (`0x1f 0x8b`), walks the gzip header manually (skipping the FEXTRA/FNAME/FCOMMENT/FHCRC optional fields), and inflates the raw deflate payload with the `Compression` framework's streaming API (`inflateRaw`) in 512 KB chunks.
- **Parsing**: a classic `XMLParser` delegate (`XMLTVParserDelegate`) reads `<programme start stop channel>` elements with `<title>` and `<desc>` children. Dates come in `yyyyMMddHHmmss Z` (or without zone); both formats are tried with cached POSIX formatters.
- **Memory bound**: guides can span weeks and be enormous. Only programs within a window of **−3 h … +48 h** around "now" are kept.
- Parsing runs in `Task.detached(priority: .utility)` so a 50 MB guide never blocks the main thread. The result is grouped by lowercased channel id and each channel's list is sorted by start time (which makes `EPGSnapshot.current/next` correct).

#### `Services/MockDataService.swift`
Generates the Demo Mode content (see [section 9](#9-demo-mode)):

- **12 live channels** in six groups (News, Sports, Entertainment, Kids, Music, Documentaries), streaming Apple's public HLS example streams so they actually play.
- **13 movies** and **3 series with seasons/episodes** built from the public Google sample-video bucket (Big Buck Bunny, Sintel, Tears of Steel, …) with real poster images, plots, years and ratings.
- **A synthetic EPG**: 20 programs of 45 minutes per channel, starting two hours in the past and aligned to the hour, with group-appropriate titles ("Matchday Live" on sports, "Ocean Giants" on documentaries…). Because the window includes "now", the now-playing rows and player EPG overlay all work in demo mode.

All demo ids use the `demo|…` prefix, so favorites and watch progress work in demo mode exactly like with a real playlist.

#### `Services/PlaybackCoordinator.swift`
Tiny by design: an `@Observable` holder of `current: PlayableItem?`. Calling `play(_:)` from *any* screen sets it, and `RootView`'s `fullScreenCover` presents the player. This decouples "user wants to play X" from "how the player is presented" — no view needs its own player sheet.

---

### 5.5 ViewModels/

All view models are `@MainActor @Observable final class` — the modern Observation-framework equivalent of `ObservableObject`, giving fine-grained, automatic view updates.

#### `ViewModels/LiveTVViewModel.swift`
Holds Live TV screen state: `selectedGroup` and `searchText`. `filteredChannels(from:)` applies group and case-insensitive name filters. Pure function of input → trivially testable.

#### `ViewModels/MoviesViewModel.swift`
Identical pattern for the movie grid (`filteredMovies(from:)`).

#### `ViewModels/SeriesViewModel.swift`
Two view models:

- **`SeriesViewModel`** — grid filtering, same pattern as movies.
- **`SeriesDetailViewModel`** — owns one series' episode data: `state` (loading/loaded/failed), `seasons` (sorted), `episodesBySeason`, and `selectedSeason`. `load(using:)` asks `ContentStore.episodes(for:)` (which hits the network for Xtream) and keeps the selected season valid across reloads.

#### `ViewModels/SearchViewModel.swift`
Cross-content search. Requires ≥ 2 characters (avoids massive result churn while typing), searches channels + movies + series case-insensitively, and caps each section at 30 results to keep the list snappy on 100k-entry playlists.

#### `ViewModels/PlayerViewModel.swift`
The largest view model — everything about playback except drawing:

- **Lifecycle**: `start()` builds the `AVPlayerItem`, seeks to a saved resume position (VOD only, if > 15 s in), starts playback, and disables the idle timer (screen stays awake). `stop()` saves progress, tears down observers, releases the player item, and re-enables the idle timer.
- **Observation**: KVO on `AVPlayerItem.status` (ready → read duration; failed → user-facing `failureMessage`) and on `AVPlayer.timeControlStatus` (drives `isPlaying`/`isBuffering` and the spinner). A periodic time observer (0.5 s) drives the seek bar via `currentTime` — unless the user `isSeeking`, so the slider doesn't fight the stream.
- **Controls logic**: `togglePlayPause`, `skip(by:)` (±10 s, VOD only — `canSkip`), precise `seek(to:)` with zero tolerance, `toggleControls` + `scheduleControlsHide` (controls auto-hide after 4 s of playback).
- **Picture in Picture**: `attach(layer:)` receives the `AVPlayerLayer` from the view and creates the `AVPictureInPictureController`; `startPictureInPicture()` triggers it.
- **Watch progress**: every ~10 s and on close, upserts a `WatchProgressEntity` keyed by the item id. Live streams never save. Past 95% of the duration the entry is *deleted* — the item is considered finished and drops off Continue Watching.
- `timeString(_:)` formats seconds as `m:ss` / `h:mm:ss` for the time labels.

#### `ViewModels/AddPlaylistViewModel.swift`
Backs the Add Playlist form: the six form fields, `canSubmit` validation, `isValidating` progress state, and `errorMessage`. `validateAndSave(context:)`:

1. Normalizes the URL (prepends `http://` when the scheme is missing, requires a host).
2. **Tests the source before saving** — downloads the M3U and checks for `#EXTM3U`/`#EXTINF`, or calls the Xtream `authenticate()` endpoint. Bad credentials or a dead URL never get persisted.
3. Saves the `PlaylistEntity` as active, deactivating all others. `RootView`'s task sees the change and loads the new source automatically.

---

### 5.6 Views/

#### `Views/Theme.swift`
Design tokens: `Color.brandPrimary` (indigo) / `.brandSecondary` (cyan), the `LinearGradient.brand` accent used on icons and progress bars, and `AppBackground` — the deep near-black backdrop with two soft radial color glows that gives glass surfaces something to refract. The `.appBackground()` modifier applies it per screen.

#### `Views/Components/PosterCard.swift`
Three reusable pieces:

- **`PosterCard`** — 2:3 poster with rounded corners, a hairline border, optional watch-progress bar overlay, title and subtitle. Used by Movies, Series, Home rows and Search.
- **`ProgressBar`** — the thin gradient capsule used everywhere progress is shown (posters, channel rows, episode thumbnails).
- **`RemoteImage`** — wraps `AsyncImage` with a consistent placeholder (gradient + SF Symbol) and proper clipping, so a missing/broken artwork URL never looks broken.

#### `Views/Components/SharedComponents.swift`
- **`GroupChipsBar`** — the horizontally scrolling category filter. The selected chip uses `.buttonStyle(.glassProminent)` (tinted, filled glass), unselected ones `.glass` — a canonical Liquid Glass pattern.
- **`SectionHeader`** — icon + title used by every Home section.
- **`ChannelRow`** — logo in a soft glass square, channel name, favorite star, and *either* the current EPG program with its airing progress *or* the channel's group when no guide data exists.
- **`LoadingStateView` / `ErrorStateView`** — the shared loading spinner and the retry screen used by every tab, so all failure states look and behave identically.

#### `Views/Home/HomeView.swift`
The dashboard. Switches on `ContentStore.state`; when loaded it renders lazy horizontal sections:

1. **Demo banner** (only in demo mode) — explains the sample content and offers "Add Playlist".
2. **Stats header** — three glass tiles with channel/movie/series counts.
3. **Continue Watching** — driven by a `@Query` on `WatchProgressEntity` sorted by recency; each card starts playback directly from the stored `PlayableItem`.
4. **Favorites** — `FavoriteEntity` keys resolved against the store (`channel(forKey:)`…); unresolvable keys (e.g. from another playlist) are silently filtered.
5. **Live Now**, **Recently Added Movies**, **Series** rows.

Also hosts the Settings and Add Playlist sheets (gear icon in the toolbar).

#### `Views/LiveTV/LiveTVView.swift`
Category chips + channel list (`List` for native swipe actions). Each row shows live EPG info, tapping plays immediately, swiping toggles the favorite (inserting/deleting a `FavoriteEntity`). `.searchable` provides inline filtering; pull-to-refresh reloads the playlist.

#### `Views/Movies/MoviesView.swift`
Adaptive-column `LazyVGrid` of `PosterCard`s with the same chips/search/refresh pattern. Navigates to `MovieDetailView`.

#### `Views/Movies/MovieDetailView.swift`
Poster + metadata header, rating, group badge, watched-percentage bar, **Play/Resume** button (label switches based on saved progress), favorite toggle, synopsis, and detail rows (genre/cast/duration/year). For Xtream movies with no plot, `.task { loadDetailsIfNeeded() }` fetches `get_vod_info` once and fills the metadata in place — the movie is held in `@State` precisely so it can be enriched after appearing.

#### `Views/Series/SeriesView.swift`
Grid of series, same pattern as Movies.

#### `Views/Series/SeriesDetailView.swift`
Header (poster, rating, favorite button, plot) + episode browser. Episodes load through `SeriesDetailViewModel` (`.task { model.load(using: store) }`); a glass season picker appears when there's more than one season. Each episode row shows thumbnail, watch progress overlay, `E# · Title`, duration, and plays on tap via `episode.playable(in: series)`.

#### `Views/Search/SearchView.swift`
The search tab. Below 2 characters it shows a hint; otherwise sectioned results (Live Channels / Movies / Series) — channels play instantly, movies/series navigate to their detail pages.

#### `Views/Settings/SettingsView.swift`
Four sections:

- **Playlists** — all saved sources with type icon and active checkmark; tap to switch active (the content reloads automatically via `RootView`), swipe to delete (with re-activation of a remaining playlist so the app never has zero active sources while some exist).
- **TV Guide** — loaded program count, background-loading spinner, manual "Refresh Guide".
- **Library** — clear watch history / clear favorites, both behind confirmation dialogs.
- **About** — version and credits.

#### `Views/Settings/AddPlaylistView.swift`
The add-source form: segmented M3U/Xtream picker that swaps the relevant fields (URL+optional EPG vs. server+username+password), inline error display, and a **Connect & Save** button showing a progress state while `AddPlaylistViewModel` validates against the live server. Dismissal is blocked mid-validation.

#### `Views/Player/PlayerView.swift`
The full-screen player, layered bottom-to-top:

1. Black backdrop + `PlayerLayerView` (the video).
2. **Gesture layer** — single tap toggles controls; invisible left/right halves catch double-taps for ∓10 s skips.
3. Buffering spinner / failure message when relevant.
4. **Controls overlay** (when visible), with top/bottom gradient shades for legibility:
   - *Top bar* (in a `GlassEffectContainer` so adjacent glass shapes merge fluidly): close button, title capsule (for live channels the subtitle is the current EPG program), AirPlay picker, PiP button, aspect-fill toggle.
   - *Center*: glass play/pause and ±10 s buttons (skip buttons hidden for live).
   - *Bottom*: for live — a red **LIVE** badge plus "Next: …" EPG capsule; for VOD — a seek slider with elapsed/total time labels in a rounded glass panel.

Lifecycle: `onAppear` gives the view model its `ModelContext` (for progress persistence) and starts playback; `onDisappear` stops and saves. The status bar and home indicator fade with the controls.

#### `Views/Player/PlayerSupport.swift`
UIKit bridges the player needs:

- **`PlayerContainerUIView` / `PlayerLayerView`** — SwiftUI can't host an `AVPlayerLayer` directly. The UIView overrides `layerClass` so its backing layer *is* the player layer (automatically resizing with the view), and the representable passes that layer up via `onLayerReady` (dispatched async to avoid mutating state during view construction) so the view model can create the PiP controller. Also applies the aspect-fit/fill `videoGravity`.
- **`AirPlayButton`** — wraps `AVRoutePickerView`, the system AirPlay device picker, tinted for the dark player UI.

---

## 6. How Data Flows

**Adding a source → seeing content:**

```
AddPlaylistView ──▶ AddPlaylistViewModel.validateAndSave()
                        │  (tests server, saves PlaylistEntity as active)
                        ▼
                SwiftData change observed by RootView's @Query
                        ▼
                RootView .task(id: activePlaylistID)
                        ▼
                ContentStore.activateIfNeeded(PlaylistConfig)
                   ├── M3U:    download → M3UParser (background) ─┐
                   └── Xtream: 6 parallel API calls → map DTOs  ──┤
                                                                  ▼
                     channels / movies / series published (@Observable)
                                                                  ▼
                        every tab re-renders automatically
                     (EPG downloads/parses in a background task
                      and appears when ready)
```

**Playing something:**

```
Any view ──▶ playback.play(item.playable)
                    ▼
        PlaybackCoordinator.current = item
                    ▼
        RootView fullScreenCover presents PlayerView
                    ▼
        PlayerViewModel: AVPlayer + resume position + observers
                    ▼
        on close: watch progress saved → Continue Watching updates
```

## 7. The Content Identity Scheme

Every piece of content has a **stable string key**:

```
<playlistUUID>|live|<streamID or URL>     e.g. "demo|live|3"
<playlistUUID>|movie|<streamID or URL>
<playlistUUID>|series|<seriesID or title>
<playlistUUID>|ep|<episodeID or URL>
```

Favorites and watch progress store *only* these keys (plus display metadata for progress). Because the key embeds the playlist id, content from different playlists never collides; because it uses server ids/URLs, keys survive refreshes. **Do not change this format** without migrating stored favorites/progress.

## 8. Persistence (SwiftData)

| Entity | What it stores | Written by | Read by |
|---|---|---|---|
| `PlaylistEntity` | Source config + `isActive` | AddPlaylistViewModel, SettingsView | RootView, SettingsView |
| `FavoriteEntity` | Content key + kind + date | LiveTVView, MovieDetailView, SeriesDetailView | HomeView, LiveTVView, detail views |
| `WatchProgressEntity` | Resume position + display data + stream URL | PlayerViewModel | HomeView (Continue Watching), detail views (progress bars) |

The container is created once in `StreamAppApp` and reaches views via `.modelContainer(_:)` / `@Environment(\.modelContext)` / `@Query`. There is no CloudKit sync configured; everything is on-device.

## 9. Demo Mode

When **no playlist exists** (first launch, or after deleting all playlists), `RootView` calls `ContentStore.activateIfNeeded(nil)`, which activates **demo content** from `MockDataService` instead of showing an empty app:

- Every screen — Home, Live TV (with a working TV guide), Movies, Series, Search, the player — is fully functional.
- The streams are public test assets (Apple HLS examples, Blender open movies from the Google sample bucket), so **playback genuinely works**, including Continue Watching and favorites.
- Home shows a "Demo Mode" glass banner with an *Add Playlist* button.
- The moment a real playlist is added, `isDemo` flips off and real content replaces the samples. Demo favorites/progress remain in the database keyed under `demo|…` and simply reappear if demo mode returns.

## 10. Liquid Glass Usage

iOS 26 Liquid Glass APIs used across the app:

| API | Where |
|---|---|
| `.glassEffect(.regular, in: shape)` | Stat tiles, demo banner, title capsule, LIVE badge, episode rows, channel avatars, seek-bar panel |
| `GlassEffectContainer` | Player top bar and center controls (adjacent glass shapes blend/merge) |
| `.buttonStyle(.glass)` | Secondary buttons: player controls, unselected chips, favorite buttons |
| `.buttonStyle(.glassProminent)` + `.tint` | Primary actions: Play/Resume, Add Playlist, selected chips, Connect & Save |
| `Tab(_, systemImage:, role: .search)` | Search tab with system search placement |
| `.tabBarMinimizeBehavior(.onScrollDown)` | Floating tab bar that collapses while scrolling |

Design rules followed: glass is reserved for the *control layer* floating above content; content itself (posters, video) stays opaque; the dark gradient background (`AppBackground`) gives glass surfaces color to refract.

## 11. Building, Running & Regenerating the Project

```sh
# one-time
brew install xcodegen

# after adding/removing files or editing project.yml
cd ~/Desktop/StreamApp
xcodegen generate

# open & run
open StreamApp.xcodeproj      # scheme: StreamApp, any iOS 26 simulator

# or from the command line
xcodebuild -project StreamApp.xcodeproj -scheme StreamApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

`StreamApp.xcodeproj` and `Info.plist` are **generated artifacts** — never edit them by hand; change `project.yml` instead.

## 12. How to Extend the App

**Add a new screen** — create a view model in `ViewModels/` (`@MainActor @Observable`), a view in `Views/<Feature>/`, read shared data via `@Environment(ContentStore.self)`, and add a `Tab` in `MainTabView` (or a `NavigationLink` from an existing screen). Run `xcodegen generate`.

**Add a new source type** (e.g. Stalker portal) — add a case to `PlaylistKind`, a service next to `XtreamService`, a loader branch in `ContentStore.load(_:)`, and fields in `AddPlaylistView`/`AddPlaylistViewModel`. Everything downstream (UI, favorites, player) works untouched because it only ever sees the value models.

**Add persisted data** — new `@Model` class in `PersistenceModels.swift`, register it in the `ModelContainer` in `StreamAppApp.swift`.

**Likely next features** — an app icon and asset catalog, iPad/tvOS layouts, catch-up/timeshift, recording lists, Chromecast (needs the Google Cast SDK — the only thing that would break the zero-dependency rule), parental controls, and multi-profile support.
