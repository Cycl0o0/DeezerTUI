import Foundation

struct Artist: Codable, Hashable {
    let id: String
    let name: String
}

struct Track: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let durationMs: Int64
    let artists: [Artist]
    let artistLine: String
    let albumName: String
    let artworkUrl: String
    let explicit: Bool

    var durationText: String { Self.timeText(durationMs) }

    static func timeText(_ ms: Int64) -> String {
        let s = max(0, ms) / 1000
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct Album: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let artists: [Artist]
    let artworkUrl: String
    var artistLine: String { artists.first?.name ?? "" }
}

struct Playlist: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let owner: String
    let trackCount: Int
    let artworkUrl: String
}

struct TracksResponse: Codable { let tracks: [Track] }
struct PlaylistsResponse: Codable { let playlists: [Playlist] }
struct SearchResponse: Codable {
    let tracks: [Track]
    let albums: [Album]
    let playlists: [Playlist]
    let artists: [ArtistInfo]?
}
struct ErrorResponse: Codable { let error: String }

struct CreatedPlaylist: Codable { let id: String }

struct Podcast: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String
    let artworkUrl: String
    let episodeCount: Int
}
struct PodcastsResponse: Codable { let podcasts: [Podcast] }

struct Episode: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let description: String
    let artworkUrl: String
    let durationMs: Int64
    let releaseDate: String

    var durationText: String { Track.timeText(durationMs) }
}
struct EpisodesResponse: Codable { let episodes: [Episode] }

struct Device: Codable, Hashable, Identifiable {
    let name: String
    let addr: String
    let client: String
    let version: String

    var id: String { addr }

    var typeLabel: String {
        switch client {
        case "tui": return "Terminal"
        case "darwin", "macos": return "macOS"
        case "windows": return "Windows"
        case "linux", "gnome", "kde": return "Linux"
        case "ios": return "iPhone"
        case "android": return "Android"
        default: return client.isEmpty ? "Device" : client.capitalized
        }
    }

    var symbol: String {
        switch client {
        case "tui": return "terminal"
        case "darwin", "macos": return "laptopcomputer"
        case "windows": return "pc"
        case "linux", "gnome", "kde": return "desktopcomputer"
        case "ios": return "iphone"
        case "android": return "apps.iphone"
        default: return "music.note.tv"
        }
    }
}

struct Account: Codable {
    let userId: String
    let name: String
    let offer: String
    let canHq: Bool
    let canHifi: Bool
    let premium: Bool
    let loggedIn: Bool
}

struct ArtistInfo: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let artworkUrl: String
    let nbFans: Int
}

struct ChartsResponse: Codable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [ArtistInfo]
    let playlists: [Playlist]
}

struct ArtistProfile: Codable {
    let artist: ArtistInfo
    let top: [Track]
    let albums: [Album]
    let related: [ArtistInfo]
}

struct LyricLine: Codable, Hashable {
    let timeMs: Int64
    let text: String
}

struct Lyrics: Codable {
    let plain: String
    let synced: [LyricLine]
    let isSynced: Bool
}

enum PlayerState: Int {
    case stopped = 0, loading, playing, paused, errored
}
