import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject var app: AppState

    private var progress: Double {
        app.durationMs > 0 ? min(1, Double(app.positionMs) / Double(app.durationMs)) : 0
    }

    var body: some View {
        Button { app.showNowPlaying = true } label: {
            ZStack(alignment: .bottom) {
                HStack(spacing: 12) {
                    Artwork(url: app.current?.artworkUrl ?? "", size: 42, radius: 6)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if app.current?.explicit == true { ExplicitBadge() }
                            Text(app.current?.name ?? "Nothing playing")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DZ.textPri).lineLimit(1)
                        }
                        Text(app.current?.artistLine ?? "")
                            .font(.system(size: 11)).foregroundStyle(DZ.textSec).lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 18) {
                        Button {
                            app.togglePause()
                        } label: {
                            Image(systemName: app.state == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 18)).foregroundStyle(DZ.textPri)
                        }
                        Button {
                            app.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16)).foregroundStyle(DZ.textPri)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Progress line
                if app.durationMs > 0 {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(DZ.accent)
                            .frame(width: geo.size.width * progress, height: 2)
                    }
                    .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }
}

struct NowPlayingScreen: View {
    @EnvironmentObject var app: AppState
    @State private var scrubbing = false
    @State private var scrub = 0.0
    @State private var pendingArtist = false   // open the artist after this sheet closes
    @Environment(\.dismiss) private var dismiss

    private var isPlaying: Bool { app.state == .playing }
    private var progress: Double {
        app.durationMs > 0 ? min(1, Double(app.positionMs) / Double(app.durationMs)) : 0
    }

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            if let url = app.current?.artworkUrl, !url.isEmpty {
                AsyncImage(url: URL(string: url)) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    }
                }
                .blur(radius: 60).opacity(0.3).ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DZ.textSec)
                    }
                    Spacer()
                    Text("Now Playing")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(DZ.textPri)
                    Spacer()
                    Button {
                        app.showDevicePicker = true
                        app.discoverDevices()
                    } label: {
                        Image(systemName: "rectangle.connected.to.line.below")
                            .font(.system(size: 18))
                            .foregroundStyle(app.isConnectedRemote ? DZ.accent : DZ.textSec)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 20)

                // Large artwork
                Artwork(url: app.current?.artworkUrl ?? "", size: 280, radius: 16)
                    .shadow(radius: 24, y: 12)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 28)

                // Track info + like
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            if app.current?.explicit == true { ExplicitBadge() }
                            Text(app.current?.name ?? "Nothing playing")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(DZ.textPri).lineLimit(1)
                        }
                        Text(app.current?.artistLine ?? "")
                            .font(.system(size: 16)).foregroundStyle(DZ.textSec).lineLimit(1)
                    }
                    Spacer()
                    Button { app.toggleLikeCurrent() } label: {
                        Image(systemName: app.isCurrentLiked ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundStyle(app.isCurrentLiked ? DZ.accent : DZ.textSec)
                    }
                    .disabled(app.current == nil || app.playingEpisode)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 18)

                // Scrubber
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { scrubbing ? scrub : progress },
                            set: { scrub = $0 }),
                        in: 0...1,
                        onEditingChanged: { editing in
                            scrubbing = editing
                            if !editing { app.seek(toFraction: scrub) }
                        })
                    .tint(DZ.accent)
                    .padding(.horizontal, 28)

                    HStack {
                        Text(Track.timeText(
                            scrubbing ? Int64(scrub * Double(app.durationMs)) : app.positionMs))
                        .font(.caption).monospacedDigit().foregroundStyle(DZ.textSec)
                        Spacer()
                        Text(Track.timeText(app.durationMs))
                            .font(.caption).monospacedDigit().foregroundStyle(DZ.textSec)
                    }
                    .padding(.horizontal, 28)
                }

                Spacer().frame(height: 22)

                // Transport controls
                HStack(spacing: 36) {
                    Button { app.setShuffle(!app.shuffle) } label: {
                        Image(systemName: app.shuffle ? "shuffle.circle.fill" : "shuffle")
                            .font(.system(size: 22))
                            .foregroundStyle(app.shuffle ? DZ.accent : DZ.textSec)
                    }
                    Button { app.prev() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28)).foregroundStyle(DZ.textPri)
                    }
                    Button { app.togglePause() } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64)).foregroundStyle(DZ.accent)
                    }
                    Button { app.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28)).foregroundStyle(DZ.textPri)
                    }
                    Button { app.cycleRepeat() } label: {
                        Image(systemName: app.repeatMode == .one ? "repeat.1" : "repeat")
                            .font(.system(size: 22))
                            .foregroundStyle(app.repeatMode == .off ? DZ.textSec : DZ.accent)
                    }
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 22)

                // Volume
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill").foregroundStyle(DZ.textSec)
                    Slider(
                        value: Binding(get: { app.volume }, set: { app.setVolume($0) }),
                        in: 0...1)
                    .tint(DZ.accent)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(DZ.textSec)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 18)

                // Secondary actions
                HStack(spacing: 32) {
                    Button { app.showLyrics = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "quote.bubble").font(.system(size: 22))
                            Text("Lyrics").font(.caption2)
                        }
                        .foregroundStyle(DZ.textSec)
                    }
                    .disabled(app.current == nil)

                    Button {
                        // The artist sheet lives on the main UI (also opened from
                        // track rows), so close now-playing first, then open it.
                        guard app.current?.artists.first != nil else { return }
                        pendingArtist = true
                        dismiss()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "music.mic").font(.system(size: 22))
                            Text("Artist").font(.caption2)
                        }
                        .foregroundStyle(DZ.textSec)
                    }
                    .disabled(app.current?.artists.first == nil)

                    if !app.outputFormat.isEmpty {
                        VStack(spacing: 4) {
                            Image(systemName: "waveform").font(.system(size: 22))
                                .foregroundStyle(DZ.accent)
                            Text(app.outputFormat).font(.caption2)
                                .foregroundStyle(DZ.accent).lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 28).padding(.bottom, 20)

                Spacer()
            }
        }
        // Lyrics + Connect are presented from here (within the now-playing sheet)
        // so they appear over it rather than failing on a hidden ancestor.
        .sheet(isPresented: $app.showLyrics) {
            LyricsView().environmentObject(app)
        }
        .sheet(isPresented: $app.showDevicePicker) {
            DevicePickerView().environmentObject(app)
        }
        .onDisappear {
            if pendingArtist {
                pendingArtist = false
                app.openArtistForCurrent()
            }
        }
    }
}
