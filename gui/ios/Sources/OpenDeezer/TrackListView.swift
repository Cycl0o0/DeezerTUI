import SwiftUI

struct TrackListView: View {
    @EnvironmentObject var app: AppState
    let tracks: [Track]
    let title: String
    let artwork: String
    let isLiked: Bool
    let heroSymbol: String
    let subtitle: String

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            List {
                Section {
                    TrackHeroHeader(
                        title: title, artwork: artwork, isLiked: isLiked,
                        heroSymbol: heroSymbol, subtitle: subtitle, trackCount: tracks.count
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { idx, t in
                        TrackRow(index: idx, track: t, isCurrent: app.current?.id == t.id) {
                            app.play(t, in: tracks)
                        }
                        .listRowBackground(app.current?.id == t.id ? DZ.nowTint : Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct TrackHeroHeader: View {
    @EnvironmentObject var app: AppState
    let title: String
    let artwork: String
    let isLiked: Bool
    let heroSymbol: String
    let subtitle: String
    let trackCount: Int

    var body: some View {
        VStack(spacing: 16) {
            if isLiked || artwork.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [DZ.accentMag, DZ.accent],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: heroSymbol)
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                    )
                    .shadow(radius: 14, y: 6)
            } else {
                Artwork(url: artwork, size: 180, radius: 12)
                    .shadow(radius: 14, y: 6)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DZ.textPri)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DZ.textSec)
            }

            HStack(spacing: 16) {
                Button { app.playAll() } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.borderedProminent).tint(DZ.accent)

                Button { app.shuffleAll() } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered).tint(DZ.accent)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

struct TrackRow: View {
    @EnvironmentObject var app: AppState
    let index: Int
    let track: Track
    let isCurrent: Bool
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    if isCurrent {
                        Image(systemName: "waveform").foregroundStyle(DZ.accent)
                    } else {
                        Text("\(index + 1)")
                            .foregroundStyle(DZ.textSec).monospacedDigit()
                    }
                }
                .frame(width: 28)

                Artwork(url: track.artworkUrl, size: 40, radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if track.explicit { ExplicitBadge() }
                        Text(track.name)
                            .lineLimit(1)
                            .foregroundStyle(isCurrent ? DZ.accent : DZ.textPri)
                            .fontWeight(isCurrent ? .semibold : .regular)
                    }
                    Text(track.artistLine)
                        .font(.caption).foregroundStyle(DZ.textSec).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(track.durationText)
                    .font(.caption).foregroundStyle(DZ.textSec).monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onPlay() } label: { Label("Play", systemImage: "play.fill") }
            Button { app.toggleLike(track) } label: {
                Label(
                    app.isLiked(track) ? "Unlike" : "Like",
                    systemImage: app.isLiked(track) ? "heart.fill" : "heart"
                )
            }
            Button { app.beginAddToPlaylist(track) } label: {
                Label("Add to Playlist…", systemImage: "text.badge.plus")
            }
            if let aid = track.artists.first?.id {
                Button { app.openArtist(aid) } label: {
                    Label("Go to Artist", systemImage: "music.mic")
                }
            }
        }
    }
}
