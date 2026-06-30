import Foundation
import SwiftUI

enum AppSection: Hashable {
    case liked, playlists, search, charts, flow, podcasts
}

enum RepeatMode: Int { case off, all, one }

struct AppSettings {
    var quality: Int
    var gapless: Bool
    var crossfadeMS: Int

    static func load() -> AppSettings {
        let ud = UserDefaults.standard
        return AppSettings(
            quality: ud.object(forKey: "quality") != nil ? ud.integer(forKey: "quality") : 1,
            gapless: ud.object(forKey: "gapless") != nil ? ud.bool(forKey: "gapless") : true,
            crossfadeMS: ud.integer(forKey: "crossfadeMS")
        )
    }

    func save() {
        let ud = UserDefaults.standard
        ud.set(quality, forKey: "quality")
        ud.set(gapless, forKey: "gapless")
        ud.set(crossfadeMS, forKey: "crossfadeMS")
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var loggedIn = false
    @Published var accountBlocked = false
    @Published var loginError: String?
    @Published var busy = false
    @Published var userID = ""
    @Published var account: Account?
    @Published var replayGain = false
    @Published var showNowPlaying = false

    @Published var showLoginWeb = false
    @Published var manualARL = ""
    private var webLoginAttempted = false

    @Published var settings = AppSettings.load()
    private var started = false

    let nowPlaying = NowPlayingController()

    @Published var section: AppSection = .liked
    @Published var tracks: [Track] = []
    @Published var listTitle = "Liked Songs"
    @Published var listArtwork = ""
    @Published var listIsLiked = true
    @Published var listHeroSymbol = "heart.fill"
    @Published var listSubtitle = ""
    @Published var playlists: [Playlist] = []
    @Published var searchTracks: [Track] = []
    @Published var searchAlbums: [Album] = []
    @Published var searchArtists: [ArtistInfo]? = nil
    @Published var searchPlaylists: [Playlist] = []
    @Published var query = ""

    @Published var likedIDs: Set<String> = []

    @Published var chartAlbums: [Album] = []
    @Published var chartArtists: [ArtistInfo] = []
    @Published var chartPlaylists: [Playlist] = []

    @Published var showAddToPlaylist = false
    @Published var addTarget: Track?
    @Published var pickerPlaylists: [Playlist] = []
    @Published var pickerLoading = false

    @Published var showCreatePlaylist = false
    @Published var renameTarget: Playlist?
    @Published var deleteTarget: Playlist?

    @Published var podcastQuery = ""
    @Published var podcasts: [Podcast] = []
    @Published var podcastEpisodes: [Episode] = []
    @Published var openedPodcast: Podcast?
    @Published var podcastsLoading = false

    @Published var showDevicePicker = false
    @Published var devices: [Device] = []
    @Published var devicesLoading = false
    @Published var connectedDeviceAddr = ""

    @Published var showLyrics = false
    @Published var currentLyrics: Lyrics?
    @Published var lyricsLoading = false
    private var lyricsCache: [String: Lyrics] = [:]
    private var lyricsTrackID: String?

    @Published var showArtist = false
    @Published var artistProfile: ArtistProfile?
    @Published var artistLoading = false

    @Published var current: Track?
    @Published var state: PlayerState = .stopped
    @Published var outputFormat = ""
    @Published var positionMs: Int64 = 0
    @Published var durationMs: Int64 = 0
    @Published var volume: Double = 1
    @Published var shuffle = false
    @Published var repeatMode: RepeatMode = .off
    @Published var playingEpisode = false

    private var queueIndex = 0
    private var lastFinished = 0
    private var lastState: PlayerState = .stopped
    private var timer: Timer?

    // MARK: login

    func start() {
        guard !started else { return }
        started = true
        guard let arl = Self.loadARL(), !arl.isEmpty else { return }
        attemptLogin(arl: arl, persist: false)
    }

    func beginWebLogin() {
        loginError = nil
        webLoginAttempted = false
        showLoginWeb = true
    }

    func webLoginCaptured(arl: String) {
        let v = arl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, !webLoginAttempted, !busy else { return }
        webLoginAttempted = true
        attemptLogin(arl: v, persist: true) { ok in
            if ok { self.showLoginWeb = false }
            else { self.webLoginAttempted = false }
        }
    }

    func loginWithManualARL() {
        let v = manualARL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, !busy else { return }
        attemptLogin(arl: v, persist: true)
    }

    private func attemptLogin(arl: String, persist: Bool,
                              completion: ((Bool) -> Void)? = nil) {
        busy = true
        loginError = nil
        Task.detached {
            let ok = Engine.initialize(arl: arl)
            let acct = ok ? Engine.account() : nil
            await MainActor.run {
                self.busy = false
                if ok {
                    if persist { Self.saveARL(arl) }
                    self.finishLogin(account: acct)
                } else {
                    self.loginError = "Login failed — invalid or expired ARL."
                }
                completion?(ok)
            }
        }
    }

    private func finishLogin(account acct: Account?) {
        userID = acct?.userId ?? ""
        account = acct
        if let a = acct, !a.premium {
            accountBlocked = true
            loggedIn = true
            return
        }
        accountBlocked = false
        loggedIn = true
        volume = Engine.volume
        replayGain = Engine.replayGain
        Engine.setQuality(settings.quality)
        Engine.setGapless(settings.gapless)
        Engine.setCrossfadeMS(settings.crossfadeMS)
        connectedDeviceAddr = Engine.connectedDevice
        nowPlaying.registerCommands(app: self)
        startTimer()
        loadFavorites()
    }

    static func loadARL() -> String? {
        if let v = ProcessInfo.processInfo.environment["DEEZER_ARL"], !v.isEmpty { return v }
        return UserDefaults.standard.string(forKey: "deezer_arl")
    }

    static func saveARL(_ arl: String) {
        UserDefaults.standard.set(arl, forKey: "deezer_arl")
    }

    var accountLabel: String {
        if let a = account, !a.name.isEmpty {
            return a.offer.isEmpty ? a.name : "\(a.name) · \(a.offer)"
        }
        return userID.isEmpty ? "—" : "user \(userID)"
    }

    var qualityEntitlementNote: String? {
        guard let a = account else { return nil }
        let plan = a.offer.isEmpty ? "plan" : "\(a.offer) plan"
        if settings.quality >= 2 && !a.canHifi {
            return "Your \(plan) doesn't include HiFi (FLAC); playback falls back to MP3."
        }
        if settings.quality >= 1 && !a.canHq {
            return "Your \(plan) doesn't include High (MP3 320); playback falls back to MP3 128."
        }
        return nil
    }

    // MARK: browse

    func loadFavorites() {
        listTitle = "Liked Songs"
        listArtwork = ""
        listIsLiked = true
        listHeroSymbol = "heart.fill"
        busy = true
        Task.detached {
            let ts = Engine.favorites()
            await MainActor.run {
                self.tracks = ts
                self.likedIDs = Set(ts.map { $0.id })
                self.busy = false
            }
        }
    }

    func loadPlaylists() {
        busy = true
        Task.detached {
            let ps = Engine.playlists()
            await MainActor.run { self.playlists = ps; self.busy = false }
        }
    }

    func openPlaylist(_ p: Playlist) {
        listTitle = p.name
        listArtwork = p.artworkUrl
        listIsLiked = false
        listSubtitle = p.owner.isEmpty ? "Playlist" : "Playlist · \(p.owner)"
        runList { Engine.playlistTracks(p.id) }
    }

    func loadCharts() {
        listTitle = "Charts"
        listIsLiked = false
        listSubtitle = "Top worldwide"
        busy = true
        Task.detached {
            let c = Engine.charts()
            await MainActor.run {
                self.tracks = c?.tracks ?? []
                self.chartAlbums = c?.albums ?? []
                self.chartArtists = c?.artists ?? []
                self.chartPlaylists = c?.playlists ?? []
                self.listArtwork = self.tracks.first?.artworkUrl ?? ""
                self.busy = false
            }
        }
    }

    func loadFlow() {
        listTitle = "Flow"
        listArtwork = ""
        listIsLiked = true
        listHeroSymbol = "infinity"
        listSubtitle = "Your personal soundtrack"
        busy = true
        Task.detached {
            let ts = Engine.flow()
            await MainActor.run {
                self.tracks = ts
                self.busy = false
                if let first = ts.first {
                    self.shuffle = false
                    self.play(first, in: ts)
                }
            }
        }
    }

    func openAlbum(_ a: Album) {
        listTitle = a.name
        listArtwork = a.artworkUrl
        listIsLiked = false
        listSubtitle = a.artistLine.isEmpty ? "Album" : "Album · \(a.artistLine)"
        runList { Engine.albumTracks(a.id) }
    }

    func openAlbumFromChart(_ a: Album) { openAlbum(a) }

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
            let r = Engine.search(q)
            await MainActor.run {
                self.searchTracks = r?.tracks ?? []
                self.searchAlbums = r?.albums ?? []
                self.searchArtists = r?.artists
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

    // MARK: lyrics

    func loadLyricsIfNeeded() {
        guard let id = current?.id, !id.isEmpty else {
            currentLyrics = nil; lyricsTrackID = nil; lyricsLoading = false
            return
        }
        if lyricsTrackID == id { return }
        lyricsTrackID = id
        if let cached = lyricsCache[id] {
            currentLyrics = cached
            return
        }
        currentLyrics = nil
        lyricsLoading = true
        Task.detached {
            let ly = Engine.lyrics(id)
            await MainActor.run {
                self.lyricsLoading = false
                guard self.lyricsTrackID == id else { return }
                if let ly { self.lyricsCache[id] = ly }
                self.currentLyrics = ly
            }
        }
    }

    // MARK: artist

    func openArtist(_ id: String) {
        guard !id.isEmpty else { return }
        showArtist = true
        artistProfile = nil
        artistLoading = true
        Task.detached {
            let p = Engine.artistProfile(id)
            await MainActor.run {
                self.artistLoading = false
                self.artistProfile = p
            }
        }
    }

    func openArtistForCurrent() {
        guard let id = current?.artists.first?.id else { return }
        openArtist(id)
    }

    func openAlbumFromArtist(_ a: Album) {
        showArtist = false
        openAlbum(a)
    }

    // MARK: likes

    func isLiked(_ track: Track) -> Bool { likedIDs.contains(track.id) }
    var isCurrentLiked: Bool {
        guard let c = current, !playingEpisode else { return false }
        return likedIDs.contains(c.id)
    }

    func toggleLike(_ track: Track) {
        let id = track.id
        if likedIDs.contains(id) {
            likedIDs.remove(id)
            Task.detached { Engine.removeFavorite(id) }
        } else {
            likedIDs.insert(id)
            Task.detached { Engine.addFavorite(id) }
        }
    }

    func toggleLikeCurrent() {
        guard let c = current, !playingEpisode else { return }
        toggleLike(c)
    }

    // MARK: add-to-playlist

    func beginAddToPlaylist(_ track: Track) {
        addTarget = track
        pickerPlaylists = []
        pickerLoading = true
        showAddToPlaylist = true
        Task.detached {
            let ps = Engine.playlists()
            await MainActor.run {
                self.pickerPlaylists = ps
                self.pickerLoading = false
            }
        }
    }

    func addTargetTrack(toPlaylist playlistID: String) {
        guard let t = addTarget else { return }
        let tid = t.id
        showAddToPlaylist = false
        addTarget = nil
        Task.detached { Engine.addToPlaylist(playlistID, tid) }
    }

    func createPlaylistAndAddTarget(title: String) {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let t = addTarget else { return }
        let tid = t.id
        showAddToPlaylist = false
        addTarget = nil
        Task.detached {
            if let pid = Engine.createPlaylist(name) { Engine.addToPlaylist(pid, tid) }
        }
    }

    // MARK: playlist management

    func beginRename(_ p: Playlist) { renameTarget = p }

    func createPlaylist(title: String) {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        busy = true
        Task.detached {
            _ = Engine.createPlaylist(name)
            let ps = Engine.playlists()
            await MainActor.run { self.playlists = ps; self.busy = false }
        }
    }

    func renamePlaylist(_ p: Playlist, to title: String) {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let id = p.id
        Task.detached {
            Engine.renamePlaylist(id, name)
            let ps = Engine.playlists()
            await MainActor.run { self.playlists = ps }
        }
    }

    func deletePlaylist(_ p: Playlist) {
        let id = p.id
        Task.detached {
            Engine.deletePlaylist(id)
            let ps = Engine.playlists()
            await MainActor.run { self.playlists = ps }
        }
    }

    // MARK: podcasts

    func runPodcastSearch() {
        let q = podcastQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        openedPodcast = nil
        podcastEpisodes = []
        podcastsLoading = true
        Task.detached {
            let ps = Engine.searchPodcasts(q)
            await MainActor.run {
                self.podcasts = ps
                self.podcastsLoading = false
            }
        }
    }

    func openPodcast(_ p: Podcast) {
        openedPodcast = p
        podcastEpisodes = []
        podcastsLoading = true
        Task.detached {
            let eps = Engine.podcastEpisodes(p.id)
            await MainActor.run {
                self.podcastEpisodes = eps
                self.podcastsLoading = false
            }
        }
    }

    func closePodcast() { openedPodcast = nil; podcastEpisodes = [] }

    func playEpisode(_ e: Episode) {
        playingEpisode = true
        let t = Track(id: e.id, name: e.title, durationMs: e.durationMs,
                      artists: [], artistLine: openedPodcast?.name ?? "Podcast",
                      albumName: openedPodcast?.name ?? "", artworkUrl: e.artworkUrl,
                      explicit: false)
        current = t
        durationMs = e.durationMs
        positionMs = 0
        lastState = .loading
        nowPlaying.update(track: t, state: .loading, positionMs: 0, durationMs: e.durationMs)
        let id = e.id
        Task.detached { Engine.playEpisode(id) }
    }

    // MARK: connect

    var isConnectedRemote: Bool { !connectedDeviceAddr.isEmpty }
    var connectedDeviceName: String {
        devices.first(where: { $0.addr == connectedDeviceAddr })?.name ?? connectedDeviceAddr
    }

    func discoverDevices() {
        devices = []
        devicesLoading = true
        Task.detached {
            let ds = Engine.discoverDevices()
            let cur = Engine.connectedDevice
            await MainActor.run {
                self.devices = ds
                self.connectedDeviceAddr = cur
                self.devicesLoading = false
            }
        }
    }

    func connectDevice(_ d: Device) {
        let addr = d.addr
        Task.detached {
            let ok = Engine.connectDevice(addr)
            let cur = Engine.connectedDevice
            await MainActor.run {
                if ok { self.connectedDeviceAddr = cur }
                self.showDevicePicker = false
            }
        }
    }

    func disconnectDevice() {
        connectedDeviceAddr = ""
        showDevicePicker = false
        Task.detached { Engine.disconnectDevice() }
    }

    // MARK: audio settings

    func setGapless(_ on: Bool) {
        settings.gapless = on
        Engine.setGapless(on)
        settings.save()
    }

    func setCrossfadeMS(_ ms: Int) {
        settings.crossfadeMS = ms
        Engine.setCrossfadeMS(ms)
        settings.save()
    }

    func setQuality(_ level: Int) {
        settings.quality = level
        Engine.setQuality(level)
        settings.save()
    }

    func setReplayGain(_ on: Bool) {
        replayGain = on
        Engine.setReplayGain(on)
    }

    func setShuffle(_ on: Bool) {
        shuffle = on
        Engine.setShuffle(on)
    }

    func cycleRepeat() {
        repeatMode = RepeatMode(rawValue: (repeatMode.rawValue + 1) % 3) ?? .off
        Engine.setRepeat(repeatMode.rawValue)
    }

    // MARK: playback

    func play(_ track: Track, in list: [Track]) {
        tracks = list
        queueIndex = list.firstIndex(of: track) ?? 0
        playCurrent()
    }

    private func playCurrent() {
        guard queueIndex >= 0, queueIndex < tracks.count else { return }
        playingEpisode = false
        let t = tracks[queueIndex]
        current = t
        durationMs = t.durationMs
        positionMs = 0
        lastState = .loading
        nowPlaying.update(track: t, state: .loading, positionMs: 0, durationMs: t.durationMs)
        Task.detached { Engine.play(t.id, durationMs: t.durationMs) }
    }

    func togglePause() { Engine.togglePause() }

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
        Engine.setVolume(v)
    }

    func seek(toFraction f: Double) {
        seek(toMs: Int64(max(0, min(1, f)) * Double(durationMs)))
    }

    func seek(toMs ms: Int64) {
        let clamped = max(0, min(ms, durationMs))
        positionMs = clamped
        Engine.seek(clamped)
        nowPlaying.updatePlayback(state: state, positionMs: clamped, durationMs: durationMs)
    }

    // MARK: polling

    private func startTimer() {
        lastFinished = Engine.finishedCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let s = Engine.state
        positionMs = Engine.positionMs
        durationMs = Engine.durationMs
        if s != lastState {
            lastState = s
            nowPlaying.updatePlayback(state: s, positionMs: positionMs, durationMs: durationMs)
        }
        state = s
        outputFormat = Engine.format
        if let np = Engine.nowPlaying(), np.id != current?.id {
            current = np
            durationMs = np.durationMs
            lastState = s
            nowPlaying.update(track: np, state: s, positionMs: positionMs, durationMs: np.durationMs)
        }
        let f = Engine.finishedCount
        if f != lastFinished {
            lastFinished = f
            handleAdvance()
        }
    }

    private func handleAdvance() {
        if playingEpisode { return }
        if repeatMode == .one { playCurrent(); return }
        next()
    }
}
