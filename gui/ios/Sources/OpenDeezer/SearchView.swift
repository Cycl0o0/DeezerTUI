import SwiftUI

struct SearchView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(DZ.textSec)
                    TextField("Search tracks, albums, playlists", text: $app.query)
                        .foregroundStyle(DZ.textPri)
                        .onSubmit { app.runSearch() }
                    if !app.query.isEmpty {
                        Button {
                            app.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(DZ.textSec)
                        }
                    }
                }
                .padding(12)
                .background(DZ.panelBG, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)

                if app.busy {
                    Spacer()
                    ProgressView().tint(DZ.accent)
                    Spacer()
                } else {
                    List {
                        if !app.searchTracks.isEmpty {
                            Section("Tracks") {
                                ForEach(Array(app.searchTracks.enumerated()), id: \.element.id) { i, t in
                                    TrackRow(index: i, track: t,
                                             isCurrent: app.current?.id == t.id) {
                                        app.play(t, in: app.searchTracks)
                                    }
                                    .listRowBackground(app.current?.id == t.id ? DZ.nowTint : Color.clear)
                                }
                            }
                        }
                        if let artists = app.searchArtists, !artists.isEmpty {
                            Section("Artists") {
                                ForEach(artists) { ar in
                                    Button { app.openArtist(ar.id) } label: {
                                        CompactRow(
                                            url: ar.artworkUrl, title: ar.name,
                                            sub: ar.nbFans > 0
                                                ? "\(ar.nbFans.formatted()) fans"
                                                : "Artist"
                                        )
                                    }
                                    .buttonStyle(.plain).listRowBackground(Color.clear)
                                }
                            }
                        }
                        if !app.searchAlbums.isEmpty {
                            Section("Albums") {
                                ForEach(app.searchAlbums) { a in
                                    Button { app.openAlbum(a) } label: {
                                        CompactRow(url: a.artworkUrl, title: a.name, sub: a.artistLine)
                                    }
                                    .buttonStyle(.plain).listRowBackground(Color.clear)
                                }
                            }
                        }
                        if !app.searchPlaylists.isEmpty {
                            Section("Playlists") {
                                ForEach(app.searchPlaylists) { p in
                                    Button { app.openPlaylist(p) } label: {
                                        CompactRow(url: p.artworkUrl, title: p.name,
                                                   sub: "\(p.trackCount) tracks")
                                    }
                                    .buttonStyle(.plain).listRowBackground(Color.clear)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }
}

struct CompactRow: View {
    let url: String
    let title: String
    let sub: String

    var body: some View {
        HStack(spacing: 10) {
            Artwork(url: url, size: 36, radius: 4)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(DZ.textPri).lineLimit(1)
                Text(sub).font(.caption).foregroundStyle(DZ.textSec).lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
