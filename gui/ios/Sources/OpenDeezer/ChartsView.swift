import SwiftUI

struct ChartsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    if !app.tracks.isEmpty {
                        ForEach(Array(app.tracks.enumerated()), id: \.element.id) { i, t in
                            TrackRow(index: i, track: t, isCurrent: app.current?.id == t.id) {
                                app.play(t, in: app.tracks)
                            }
                            .padding(.horizontal, 12)
                            Divider().padding(.leading, 72)
                        }
                    }

                    if !app.chartAlbums.isEmpty {
                        railHeader("Top Albums")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(app.chartAlbums) { a in
                                    TileCard(url: a.artworkUrl, title: a.name, sub: a.artistLine) {
                                        app.openAlbumFromChart(a)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !app.chartArtists.isEmpty {
                        railHeader("Top Artists")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(app.chartArtists) { ar in
                                    ArtistTileCard(artist: ar) { app.openArtist(ar.id) }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    if !app.chartPlaylists.isEmpty {
                        railHeader("Top Playlists")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(app.chartPlaylists) { p in
                                    TileCard(url: p.artworkUrl, title: p.name,
                                             sub: "\(p.trackCount) tracks") {
                                        app.openPlaylist(p)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer().frame(height: 12)
                }
            }
        }
    }

    private func railHeader(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 18, weight: .bold)).foregroundStyle(DZ.textPri)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)
    }
}

struct TileCard: View {
    let url: String
    let title: String
    let sub: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Artwork(url: url, size: 130, radius: 8).shadow(radius: 4, y: 3)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DZ.textPri).lineLimit(1)
                Text(sub).font(.caption2).foregroundStyle(DZ.textSec).lineLimit(1)
            }
            .frame(width: 130, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct ArtistTileCard: View {
    let artist: ArtistInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Artwork(url: artist.artworkUrl, size: 100, radius: 50).shadow(radius: 4, y: 3)
                Text(artist.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DZ.textPri).lineLimit(1)
                    .frame(width: 100)
            }
        }
        .buttonStyle(.plain)
    }
}
