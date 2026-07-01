import Foundation
import AppKit
import MediaPlayer

// NowPlayingController bridges the frontend's playback state to the system
// "Now Playing" surface (Control Center / lock-screen-style overlay / media
// keys). It populates MPNowPlayingInfoCenter, sets the macOS-only playbackState
// (which is what actually claims the active Now Playing slot), and routes
// MPRemoteCommandCenter events back into AppState's EXISTING handlers — it never
// duplicates transport logic.
@MainActor
final class NowPlayingController {
    private weak var app: AppState?
    private let info = MPNowPlayingInfoCenter.default()
    // Guards against a slow artwork fetch landing on a track the user skipped past.
    private var artworkToken = 0

    // MARK: command center

    /// Register the remote-command handlers once, wiring each to AppState's
    /// existing transport methods. Called at launch after a successful login.
    func registerCommands(app: AppState) {
        self.app = app
        let cc = MPRemoteCommandCenter.shared()

        // Idempotent: MPRemoteCommandCenter.shared() is a process-wide singleton,
        // so drop any handlers left by a previous login before re-adding. Without
        // this, a "Switch account" re-login stacks a second target on each command
        // and every media-key press fires twice (Next skips two tracks, etc.).
        for cmd in [cc.playCommand, cc.pauseCommand, cc.togglePlayPauseCommand,
                    cc.nextTrackCommand, cc.previousTrackCommand,
                    cc.changePlaybackPositionCommand] {
            cmd.removeTarget(nil)
        }

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak app] _ in
            guard let app else { return .commandFailed }
            if app.state != .playing { app.togglePause() }
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak app] _ in
            guard let app else { return .commandFailed }
            if app.state == .playing { app.togglePause() }
            return .success
        }

        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak app] _ in
            guard let app else { return .commandFailed }
            app.togglePause()
            return .success
        }

        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { [weak app] _ in
            guard let app else { return .commandFailed }
            app.next()
            return .success
        }

        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { [weak app] _ in
            guard let app else { return .commandFailed }
            app.prev()
            return .success
        }

        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak app] event in
            guard let app, let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            app.seek(toMs: Int64(e.positionTime * 1000))
            return .success
        }

        // Controls the engine doesn't support — gray them out.
        for cmd in [cc.skipForwardCommand, cc.skipBackwardCommand,
                    cc.seekForwardCommand, cc.seekBackwardCommand,
                    cc.changeRepeatModeCommand, cc.changeShuffleModeCommand,
                    cc.ratingCommand, cc.likeCommand, cc.dislikeCommand,
                    cc.bookmarkCommand] {
            cmd.isEnabled = false
        }
    }

    // MARK: now-playing info

    /// Full metadata push — call on each track change. Artwork loads async.
    func update(track: Track?, state: PlayerState, positionMs: Int64, durationMs: Int64) {
        guard let track else {
            artworkToken += 1
            info.nowPlayingInfo = nil
            info.playbackState = .stopped
            return
        }
        var d: [String: Any] = [:]
        d[MPMediaItemPropertyTitle] = track.name
        d[MPMediaItemPropertyArtist] = track.artistLine
        d[MPMediaItemPropertyAlbumTitle] = track.albumName
        d[MPMediaItemPropertyPlaybackDuration] = Double(max(0, durationMs)) / 1000.0
        d[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(max(0, positionMs)) / 1000.0
        d[MPNowPlayingInfoPropertyPlaybackRate] = (state == .playing) ? 1.0 : 0.0
        info.nowPlayingInfo = d
        info.playbackState = Self.mpState(state)
        loadArtwork(url: track.artworkUrl)
    }

    /// Lightweight update — call when playback state changes or on seek. The
    /// system extrapolates elapsed time from the rate, so this need not run on
    /// every poll tick (only when rate/elapsed actually jump).
    func updatePlayback(state: PlayerState, positionMs: Int64, durationMs: Int64) {
        guard var d = info.nowPlayingInfo else {
            info.playbackState = Self.mpState(state)
            return
        }
        d[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(max(0, positionMs)) / 1000.0
        d[MPNowPlayingInfoPropertyPlaybackRate] = (state == .playing) ? 1.0 : 0.0
        if durationMs > 0 {
            d[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
        }
        info.nowPlayingInfo = d
        info.playbackState = Self.mpState(state)
    }

    // MARK: helpers

    private func loadArtwork(url: String) {
        artworkToken += 1
        let token = artworkToken
        guard let u = URL(string: url) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: u), let img = NSImage(data: data) else { return }
            let art = MPMediaItemArtwork(boundsSize: img.size) { size in
                let out = NSImage(size: size)
                out.lockFocus()
                img.draw(in: NSRect(origin: .zero, size: size))
                out.unlockFocus()
                return out
            }
            DispatchQueue.main.async {
                // Discard if the user moved on while we were fetching.
                guard token == self.artworkToken, var d = self.info.nowPlayingInfo else { return }
                d[MPMediaItemPropertyArtwork] = art
                self.info.nowPlayingInfo = d
            }
        }
    }

    private static func mpState(_ s: PlayerState) -> MPNowPlayingPlaybackState {
        switch s {
        case .playing, .loading: return .playing
        case .paused:            return .paused
        case .stopped, .errored: return .stopped
        }
    }
}
