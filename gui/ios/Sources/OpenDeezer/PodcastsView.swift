import SwiftUI

struct PodcastsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            Group {
                if let show = app.openedPodcast {
                    PodcastEpisodesView(show: show)
                } else {
                    podcastBrowse
                }
            }
        }
    }

    private var podcastBrowse: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(DZ.textSec)
                TextField("Search podcasts", text: $app.podcastQuery)
                    .foregroundStyle(DZ.textPri)
                    .onSubmit { app.runPodcastSearch() }
            }
            .padding(12)
            .background(DZ.panelBG, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)

            if app.podcastsLoading {
                Spacer()
                ProgressView().tint(DZ.accent)
                Spacer()
            } else if app.podcasts.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "mic").font(.system(size: 32)).foregroundStyle(DZ.textSec)
                    Text("Search for podcasts").font(.system(size: 14)).foregroundStyle(DZ.textSec)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)],
                        spacing: 20) {
                        ForEach(app.podcasts) { p in
                            PodcastCard(podcast: p) { app.openPodcast(p) }
                        }
                    }
                    .padding(16).padding(.bottom, 12)
                }
            }
        }
    }
}

private struct PodcastCard: View {
    let podcast: Podcast
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                Artwork(url: podcast.artworkUrl, size: 150, radius: 8).shadow(radius: 6, y: 4)
                Text(podcast.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DZ.textPri).lineLimit(1)
                Text(podcast.episodeCount > 0 ? "\(podcast.episodeCount) episodes" : "Podcast")
                    .font(.caption).foregroundStyle(DZ.textSec)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PodcastEpisodesView: View {
    @EnvironmentObject var app: AppState
    let show: Podcast

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                podcastHeader
                if app.podcastsLoading {
                    HStack {
                        Spacer()
                        ProgressView().tint(DZ.accent).padding(40)
                        Spacer()
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(app.podcastEpisodes) { e in
                            EpisodeRow(
                                episode: e,
                                isCurrent: app.current?.id == e.id
                            ) {
                                app.playEpisode(e)
                            }
                            Divider().overlay(DZ.hairline).padding(.leading, 24)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private var podcastHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { app.closePodcast() } label: {
                Label("Podcasts", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered).tint(DZ.accent)

            HStack(alignment: .bottom, spacing: 20) {
                Artwork(url: show.artworkUrl, size: 120, radius: 10).shadow(radius: 14, y: 6)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Podcast")
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase).foregroundStyle(DZ.textSec)
                    Text(show.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DZ.textPri).lineLimit(2)
                    if !show.description.isEmpty {
                        Text(show.description)
                            .font(.system(size: 12)).foregroundStyle(DZ.textSec).lineLimit(3)
                    }
                }
                Spacer()
            }
        }
        .padding(20)
    }
}

private struct EpisodeRow: View {
    @EnvironmentObject var app: AppState
    let episode: Episode
    let isCurrent: Bool
    let onPlay: () -> Void

    private var meta: String {
        var parts: [String] = []
        if !episode.releaseDate.isEmpty { parts.append(episode.releaseDate) }
        if episode.durationMs > 0 { parts.append(episode.durationText) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                ZStack {
                    if isCurrent {
                        Image(systemName: "waveform").foregroundStyle(DZ.accent)
                    } else {
                        Image(systemName: "play").foregroundStyle(DZ.textSec)
                    }
                }
                .frame(width: 28)

                Artwork(url: episode.artworkUrl, size: 44, radius: 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .lineLimit(1)
                        .foregroundStyle(isCurrent ? DZ.accent : DZ.textPri)
                        .fontWeight(isCurrent ? .semibold : .regular)
                    if !meta.isEmpty {
                        Text(meta).font(.caption).foregroundStyle(DZ.textSec).lineLimit(1)
                    }
                    if !episode.description.isEmpty {
                        Text(episode.description)
                            .font(.caption2).foregroundStyle(DZ.textSec).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 20).padding(.vertical, 8)
            .background(isCurrent ? DZ.nowTint : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
