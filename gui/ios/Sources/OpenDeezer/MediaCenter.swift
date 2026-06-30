import UIKit
import MediaPlayer

@MainActor
final class NowPlayingController {
    private weak var app: AppState?
    private let info = MPNowPlayingInfoCenter.default()
    private var artworkToken = 0

    func registerCommands(app: AppState) {
        self.app = app
        let cc = MPRemoteCommandCenter.shared()

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

        for cmd in [cc.skipForwardCommand, cc.skipBackwardCommand,
                    cc.seekForwardCommand, cc.seekBackwardCommand,
                    cc.changeRepeatModeCommand, cc.changeShuffleModeCommand,
                    cc.ratingCommand, cc.likeCommand, cc.dislikeCommand,
                    cc.bookmarkCommand] {
            cmd.isEnabled = false
        }
    }

    func update(track: Track?, state: PlayerState, positionMs: Int64, durationMs: Int64) {
        guard let track else {
            artworkToken += 1
            info.nowPlayingInfo = nil
            return
        }
        var d: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyArtist: track.artistLine,
            MPMediaItemPropertyAlbumTitle: track.albumName,
            MPMediaItemPropertyPlaybackDuration: Double(max(0, durationMs)) / 1000.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(max(0, positionMs)) / 1000.0,
            MPNowPlayingInfoPropertyPlaybackRate: (state == .playing) ? 1.0 : 0.0,
        ]
        info.nowPlayingInfo = d
        loadArtwork(url: track.artworkUrl)
    }

    func updatePlayback(state: PlayerState, positionMs: Int64, durationMs: Int64) {
        guard var d = info.nowPlayingInfo else { return }
        d[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(max(0, positionMs)) / 1000.0
        d[MPNowPlayingInfoPropertyPlaybackRate] = (state == .playing) ? 1.0 : 0.0
        if durationMs > 0 {
            d[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
        }
        info.nowPlayingInfo = d
    }

    private func loadArtwork(url: String) {
        artworkToken += 1
        let token = artworkToken
        guard let u = URL(string: url) else { return }
        Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: u),
                  let img = UIImage(data: data) else { return }
            let art = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            await MainActor.run {
                guard token == self.artworkToken, var d = self.info.nowPlayingInfo else { return }
                d[MPMediaItemPropertyArtwork] = art
                self.info.nowPlayingInfo = d
            }
        }
    }
}
