import Foundation
import SwiftUI

// Section is the sidebar selection.
enum Section: Hashable {
    case liked, playlists, search
}

enum RepeatMode: Int { case off, all, one }

@MainActor
final class AppState: ObservableObject {
    @Published var loggedIn = false
    @Published var loginError: String?
    @Published var busy = false
    @Published var userID = ""
    @Published var showCredits = false
    @Published var showSettings = false

    // Persisted preferences (audio quality, close-to-tray).
    @Published var settings = AppSettings.load()
    private var started = false // guards start() against repeated onAppear

    // OS Now Playing surface + menu-bar tray / background-playback controller.
    let nowPlaying = NowPlayingController()
    let tray = TrayController()

    @Published var section: Section = .liked
    @Published var tracks: [Track] = []          // current track list / queue
    @Published var listTitle = "Liked Songs"
    @Published var listArtwork = ""              // hero artwork (empty => Liked gradient)
    @Published var listIsLiked = true            // hero style: gradient vs artwork
    @Published var listSubtitle = ""
    @Published var playlists: [Playlist] = []
    @Published var searchTracks: [Track] = []
    @Published var searchAlbums: [Album] = []
    @Published var searchPlaylists: [Playlist] = []
    @Published var query = ""

    // playback
    @Published var current: Track?
    @Published var state: PlayerState = .stopped
    @Published var outputFormat = "" // human label of the current stream format
    @Published var positionMs: Int64 = 0
    @Published var durationMs: Int64 = 0
    @Published var volume: Double = 1
    @Published var shuffle = false
    @Published var repeatMode: RepeatMode = .off

    private var queueIndex = 0
    private var lastFinished = 0
    private var lastState: PlayerState = .stopped
    private var timer: Timer?

    // MARK: login

    func start() {
        guard !started else { return } // onAppear can fire more than once
        guard let arl = Self.loadARL(), !arl.isEmpty else {
            loginError = "No ARL found. Set $DEEZER_ARL or ~/.config/opendeezer/arl.txt"
            return
        }
        started = true
        busy = true
        Task.detached {
            let ok = Core.initialize(arl: arl)
            await MainActor.run {
                self.busy = false
                self.loggedIn = ok
                if ok {
                    self.userID = Core.userID
                    self.volume = Core.volume
                    // Apply persisted audio quality, claim the OS Now Playing
                    // slot's command handlers, and wire up the tray.
                    Core.setQuality(self.settings.quality)
                    self.nowPlaying.registerCommands(app: self)
                    self.tray.closeToTray = self.settings.closeToTray
                    self.tray.attach(app: self)
                    self.startTimer()
                    self.loadFavorites()
                } else {
                    self.loginError = "Login failed — invalid or expired ARL."
                }
            }
        }
    }

    static func loadARL() -> String? {
        if let v = ProcessInfo.processInfo.environment["DEEZER_ARL"], !v.isEmpty { return v }
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Prefer the new config dir; fall back to the legacy one.
        for dir in ["opendeezer", "deezertui"] {
            let path = home.appendingPathComponent(".config/\(dir)/arl.txt")
            if let s = (try? String(contentsOf: path, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return s
            }
        }
        return nil
    }

    // MARK: browse

    func loadFavorites() {
        listTitle = "Liked Songs"
        listArtwork = ""
        listIsLiked = true
        runList { Core.favorites() }
    }
    func loadPlaylists() {
        tracks = []                  // show the grid, not a stale track list
        busy = true
        Task.detached {
            let ps = Core.playlists()
            await MainActor.run { self.playlists = ps; self.busy = false }
        }
    }
    func openPlaylist(_ p: Playlist) {
        section = .playlists
        listTitle = p.name
        listArtwork = p.artworkUrl
        listIsLiked = false
        listSubtitle = p.owner.isEmpty ? "Playlist" : "Playlist · \(p.owner)"
        runList { Core.playlistTracks(p.id) }
    }
    func openAlbum(_ a: Album) {
        listTitle = a.name
        listArtwork = a.artworkUrl
        listIsLiked = false
        listSubtitle = a.artistLine.isEmpty ? "Album" : "Album · \(a.artistLine)"
        runList { Core.albumTracks(a.id) }
    }

    // Play-all / shuffle-all from a hero header.
    func playAll() {
        guard let first = tracks.first else { return }
        shuffle = false
        play(first, in: tracks)
    }
    func shuffleAll() {
        guard !tracks.isEmpty else { return }
        shuffle = true
        play(tracks.randomElement()!, in: tracks)
    }
    func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        busy = true
        Task.detached {
            let r = Core.search(q)
            await MainActor.run {
                self.searchTracks = r?.tracks ?? []
                self.searchAlbums = r?.albums ?? []
                self.searchPlaylists = r?.playlists ?? []
                self.busy = false
            }
        }
    }

    private func runList(_ fetch: @escaping @Sendable () -> [Track]) {
        busy = true
        Task.detached {
            let ts = fetch()
            await MainActor.run { self.tracks = ts; self.busy = false }
        }
    }

    // MARK: playback

    func play(_ track: Track, in list: [Track]) {
        tracks = list
        queueIndex = list.firstIndex(of: track) ?? 0
        playCurrent()
    }

    private func playCurrent() {
        guard queueIndex >= 0, queueIndex < tracks.count else { return }
        let t = tracks[queueIndex]
        current = t
        durationMs = t.durationMs
        positionMs = 0
        lastState = .loading
        // Push the new track to the OS Now Playing surface immediately.
        nowPlaying.update(track: t, state: .loading, positionMs: 0, durationMs: t.durationMs)
        Task.detached { Core.play(t.id, durationMs: t.durationMs) }
    }

    func togglePause() { Core.togglePause() }

    func next() {
        guard !tracks.isEmpty else { return }
        if shuffle && tracks.count > 1 {
            var n = queueIndex
            while n == queueIndex { n = Int.random(in: 0..<tracks.count) }
            queueIndex = n
        } else if queueIndex + 1 < tracks.count {
            queueIndex += 1
        } else if repeatMode == .all {
            queueIndex = 0
        } else { return }
        playCurrent()
    }

    func prev() {
        guard !tracks.isEmpty else { return }
        if queueIndex > 0 { queueIndex -= 1 }
        playCurrent()
    }

    func setVolume(_ v: Double) {
        volume = v
        Core.setVolume(v)
    }

    func seek(toFraction f: Double) {
        seek(toMs: Int64(max(0, min(1, f)) * Double(durationMs)))
    }

    // seek(toMs:) is the absolute-position seek used by the scrubber and by the
    // OS "change playback position" remote command.
    func seek(toMs ms: Int64) {
        let clamped = max(0, min(ms, durationMs))
        positionMs = clamped          // optimistic; the timer reconciles
        Core.seek(clamped)
        nowPlaying.updatePlayback(state: state, positionMs: clamped, durationMs: durationMs)
    }

    // MARK: settings

    func setQuality(_ level: Int) {
        settings.quality = level
        Core.setQuality(level)
        settings.save()
    }

    func setCloseToTray(_ on: Bool) {
        settings.closeToTray = on
        tray.closeToTray = on
        settings.save()
    }

    // MARK: polling

    private func startTimer() {
        lastFinished = Core.finishedCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let s = Core.state
        positionMs = Core.positionMs
        durationMs = Core.durationMs
        // Only re-publish to the OS when the playback state actually changes —
        // the system extrapolates elapsed time from the rate between pushes.
        if s != lastState {
            lastState = s
            nowPlaying.updatePlayback(state: s, positionMs: positionMs, durationMs: durationMs)
        }
        state = s
        outputFormat = Core.format
        let f = Core.finishedCount
        if f != lastFinished {
            lastFinished = f
            if repeatMode == .one { playCurrent() } else { next() }
        }
    }
}
