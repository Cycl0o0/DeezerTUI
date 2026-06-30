import SwiftUI

// MARK: - Lyrics

struct LyricsView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    private var synced: [LyricLine] { app.currentLyrics?.synced ?? [] }
    private var isSynced: Bool { (app.currentLyrics?.isSynced ?? false) && !synced.isEmpty }
    private var plain: String { app.currentLyrics?.plain ?? "" }

    private var activeIndex: Int? {
        guard isSynced else { return nil }
        let pos = app.positionMs
        var idx: Int?
        for (i, line) in synced.enumerated() {
            if line.timeMs <= pos { idx = i } else { break }
        }
        return idx
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DZ.windowBG.ignoresSafeArea()
                VStack(spacing: 0) {
                    lyricsHeader
                    Divider().overlay(DZ.hairline)
                    lyricsContent
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { app.loadLyricsIfNeeded() }
        .onChange(of: app.current?.id) { _ in app.loadLyricsIfNeeded() }
    }

    private var lyricsHeader: some View {
        HStack(spacing: 12) {
            Artwork(url: app.current?.artworkUrl ?? "", size: 44, radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if app.current?.explicit == true { ExplicitBadge() }
                    Text(app.current?.name ?? "Lyrics")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(DZ.textPri).lineLimit(1)
                }
                Text(app.current?.artistLine ?? "")
                    .font(.system(size: 12)).foregroundStyle(DZ.textSec).lineLimit(1)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.bordered).tint(DZ.accent)
        }
        .padding(16)
    }

    @ViewBuilder private var lyricsContent: some View {
        if app.lyricsLoading {
            centeredView { ProgressView().tint(DZ.accent) }
        } else if isSynced {
            syncedBody
        } else if !plain.isEmpty {
            ScrollView {
                Text(plain)
                    .font(.system(size: 15)).foregroundStyle(DZ.textPri)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
        } else {
            centeredView {
                VStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 32)).foregroundStyle(DZ.textSec)
                    Text("No lyrics available")
                        .font(.system(size: 14)).foregroundStyle(DZ.textSec)
                }
            }
        }
    }

    private var syncedBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(synced.enumerated()), id: \.offset) { i, line in
                        Text(line.text.isEmpty ? "♪" : line.text)
                            .font(.system(size: i == activeIndex ? 19 : 16,
                                          weight: i == activeIndex ? .bold : .regular))
                            .foregroundStyle(i == activeIndex ? DZ.textPri : DZ.textSec)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { app.seek(toMs: line.timeMs) }
                            .id(i)
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 28)
            }
            .animation(.easeOut(duration: 0.2), value: activeIndex)
            .onChange(of: activeIndex) { idx in
                guard let idx else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder private func centeredView<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack { Spacer(); c(); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Artist

struct ArtistView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DZ.windowBG.ignoresSafeArea()
                if app.artistLoading && app.artistProfile == nil {
                    ProgressView().tint(DZ.accent)
                } else if let p = app.artistProfile {
                    profileBody(p)
                } else {
                    Text("Couldn't load this artist.")
                        .font(.system(size: 14)).foregroundStyle(DZ.textSec)
                }
            }
            .navigationTitle(app.artistProfile?.artist.name ?? "Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func profileBody(_ p: ArtistProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                artistHeader(p.artist)

                if !p.top.isEmpty {
                    sectionHeader("Top Tracks")
                    LazyVStack(spacing: 0) {
                        ForEach(Array(p.top.enumerated()), id: \.element.id) { i, t in
                            TrackRow(index: i, track: t, isCurrent: app.current?.id == t.id) {
                                app.play(t, in: p.top)
                            }
                            Divider().overlay(DZ.hairline).padding(.leading, 24)
                        }
                    }
                }

                if !p.albums.isEmpty {
                    sectionHeader("Albums")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(p.albums) { a in
                                AlbumCard(album: a) { app.openAlbumFromArtist(a) }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                if !p.related.isEmpty {
                    sectionHeader("Related Artists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(p.related) { ar in
                                ArtistAvatar(artist: ar) { app.openArtist(ar.id) }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func artistHeader(_ a: ArtistInfo) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Artwork(url: a.artworkUrl, size: 110, radius: 55).shadow(radius: 14, y: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text("Artist")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase).foregroundStyle(DZ.textSec)
                Text(a.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(DZ.textPri).lineLimit(2)
                if a.nbFans > 0 {
                    Text("\(a.nbFans.formatted()) fans")
                        .font(.subheadline).foregroundStyle(DZ.textSec)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 8)
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 18, weight: .bold)).foregroundStyle(DZ.textPri)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}

private struct AlbumCard: View {
    let album: Album
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                Artwork(url: album.artworkUrl, size: 130, radius: 8).shadow(radius: 6, y: 4)
                Text(album.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DZ.textPri).lineLimit(1)
                Text(album.artistLine).font(.caption2).foregroundStyle(DZ.textSec).lineLimit(1)
            }
            .frame(width: 130, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct ArtistAvatar: View {
    let artist: ArtistInfo
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 6) {
                Artwork(url: artist.artworkUrl, size: 90, radius: 45).shadow(radius: 5, y: 3)
                Text(artist.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DZ.textPri).lineLimit(1).frame(width: 90)
            }
        }
        .buttonStyle(.plain)
    }
}
