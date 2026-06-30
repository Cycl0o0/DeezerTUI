import Foundation
import Odmobile

enum Engine {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // The gomobile JSON keys use camelCase matching our Codable structs,
    // so we use the default decoder (no snake_case conversion).
    private static let camelDecoder = JSONDecoder()

    private static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? camelDecoder.decode(T.self, from: data)
    }

    // MARK: session
    @discardableResult
    static func initialize(arl: String) -> Bool { OdmobileInit(arl) }
    static var loggedIn: Bool { OdmobileLoggedIn() }

    // MARK: account
    static func account() -> Account? { decode(Account.self, OdmobileAccount()) }

    // MARK: browse
    static func favorites() -> [Track] {
        decode(TracksResponse.self, OdmobileFavorites())?.tracks ?? []
    }
    static func playlists() -> [Playlist] {
        decode(PlaylistsResponse.self, OdmobilePlaylists())?.playlists ?? []
    }
    static func playlistTracks(_ id: String) -> [Track] {
        decode(TracksResponse.self, OdmobilePlaylistTracks(id))?.tracks ?? []
    }
    static func albumTracks(_ id: String) -> [Track] {
        decode(TracksResponse.self, OdmobileAlbumTracks(id))?.tracks ?? []
    }
    static func search(_ q: String) -> SearchResponse? {
        decode(SearchResponse.self, OdmobileSearch(q))
    }
    static func charts() -> ChartsResponse? {
        decode(ChartsResponse.self, OdmobileCharts())
    }
    static func flow() -> [Track] {
        decode(TracksResponse.self, OdmobileFlow())?.tracks ?? []
    }
    static func artistTop(_ id: String) -> [Track] {
        decode(TracksResponse.self, OdmobileArtistTop(id))?.tracks ?? []
    }
    static func artistProfile(_ id: String) -> ArtistProfile? {
        decode(ArtistProfile.self, OdmobileArtistProfile(id))
    }
    static func lyrics(_ id: String) -> Lyrics? {
        decode(Lyrics.self, OdmobileLyrics(id))
    }
    static func searchPodcasts(_ q: String) -> [Podcast] {
        decode(PodcastsResponse.self, OdmobileSearchPodcasts(q))?.podcasts ?? []
    }
    static func podcastEpisodes(_ id: String) -> [Episode] {
        decode(EpisodesResponse.self, OdmobilePodcastEpisodes(id))?.episodes ?? []
    }

    // MARK: playback
    @discardableResult
    static func play(_ id: String, durationMs: Int64) -> Bool {
        OdmobilePlay(id, durationMs)
    }
    @discardableResult
    static func playEpisode(_ id: String) -> Bool { OdmobilePlayEpisode(id) }
    static func togglePause() { OdmobileTogglePause() }
    static func stop() { OdmobileStop() }
    static func seek(_ ms: Int64) { OdmobileSeek(ms) }
    static func setVolume(_ v: Double) { OdmobileSetVolume(v) }
    static var volume: Double { OdmobileVolume() }
    static var state: PlayerState { PlayerState(rawValue: OdmobileState()) ?? .stopped }
    static var positionMs: Int64 { OdmobilePositionMS() }
    static var durationMs: Int64 { OdmobileDurationMS() }
    static var finishedCount: Int { OdmobileFinishedCount() }
    static var format: String { OdmobileFormat() }

    // MARK: now playing
    private struct NPTrack: Decodable {
        let id: String
        let name: String
        let durationMs: Int64
        let artists: [Artist]?
        let artistId: String?
        let artistLine: String
        let albumName: String
        let artworkUrl: String
        let explicit: Bool
    }

    static func nowPlaying() -> Track? {
        guard let np = decode(NPTrack.self, OdmobileNowPlaying()), !np.id.isEmpty else { return nil }
        let artists: [Artist]
        if let a = np.artists, !a.isEmpty {
            artists = a
        } else if let aid = np.artistId, !aid.isEmpty {
            artists = [Artist(id: aid, name: np.artistLine)]
        } else {
            artists = []
        }
        return Track(id: np.id, name: np.name, durationMs: np.durationMs,
                     artists: artists, artistLine: np.artistLine,
                     albumName: np.albumName, artworkUrl: np.artworkUrl, explicit: np.explicit)
    }

    // MARK: settings
    static func setQuality(_ l: Int) { OdmobileSetQuality(l) }
    static var quality: Int { OdmobileQuality() }
    static func setReplayGain(_ on: Bool) { OdmobileSetReplayGain(on) }
    static var replayGain: Bool { OdmobileReplayGain() }
    static func setGapless(_ on: Bool) { OdmobileSetGapless(on) }
    static var gapless: Bool { OdmobileGapless() }
    static func setCrossfadeMS(_ ms: Int) { OdmobileSetCrossfadeMS(ms) }
    static var crossfadeMS: Int { OdmobileCrossfadeMS() }
    static func setRepeat(_ mode: Int) { OdmobileSetRepeat(mode) }
    static func setShuffle(_ on: Bool) { OdmobileSetShuffle(on ? 1 : 0) }

    // MARK: mutations
    @discardableResult
    static func addFavorite(_ id: String) -> Bool { OdmobileAddFavorite(id) }
    @discardableResult
    static func removeFavorite(_ id: String) -> Bool { OdmobileRemoveFavorite(id) }
    @discardableResult
    static func addToPlaylist(_ pid: String, _ tid: String) -> Bool {
        OdmobileAddToPlaylist(pid, tid)
    }
    @discardableResult
    static func removeFromPlaylist(_ pid: String, _ tid: String) -> Bool {
        OdmobileRemoveFromPlaylist(pid, tid)
    }
    static func createPlaylist(_ title: String) -> String? {
        decode(CreatedPlaylist.self, OdmobileCreatePlaylist(title))?.id
    }
    @discardableResult
    static func renamePlaylist(_ id: String, _ title: String) -> Bool {
        OdmobileRenamePlaylist(id, title)
    }
    @discardableResult
    static func deletePlaylist(_ id: String) -> Bool { OdmobileDeletePlaylist(id) }

    // MARK: connect
    static func discoverDevices(timeoutMS: Int = 700) -> [Device] {
        decode([Device].self, OdmobileDiscoverDevices(timeoutMS)) ?? []
    }
    @discardableResult
    static func connectDevice(_ addr: String) -> Bool { OdmobileConnectDevice(addr) }
    static func disconnectDevice() { OdmobileDisconnectDevice() }
    static var connectedDevice: String { OdmobileConnectedDevice() }

    // MARK: web remote
    struct WebRemoteInfo: Decodable {
        let enabled: Bool
        let code: String
        let url: String
        let port: Int
    }
    static func setWebRemoteEnabled(_ on: Bool) { OdmobileWebRemoteSetEnabled(on ? 1 : 0) }
    static func webRemoteInfo() -> WebRemoteInfo? {
        decode(WebRemoteInfo.self, OdmobileWebRemoteInfo())
    }
    static func webRemoteQRPNG() -> Data? { OdmobileWebRemoteQRPNG() }
}
