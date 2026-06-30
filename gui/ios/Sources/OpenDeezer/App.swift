import SwiftUI
import AVFoundation

@main
struct OpenDeezerApp: App {
    @StateObject private var app = AppState()

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .tint(DZ.accent)
                .preferredColorScheme(.dark)
                .onAppear { app.start() }
        }
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
            if app.accountBlocked {
                FreeAccountBlockedView()
            } else if app.loggedIn {
                MainTabView()
            } else {
                LoginGate()
            }
        }
        .sheet(isPresented: $app.showLoginWeb) { DeezerLoginSheet() }
        .sheet(isPresented: $app.showLyrics) { LyricsView() }
        .sheet(isPresented: $app.showArtist) { ArtistView() }
        .sheet(isPresented: $app.showAddToPlaylist) { AddToPlaylistSheet() }
        .sheet(isPresented: $app.showDevicePicker) { DevicePickerView() }
    }
}

// MARK: - Login Gate

struct LoginGate: View {
    @EnvironmentObject var app: AppState
    @State private var showManual = false

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 56)).foregroundStyle(DZ.accent)
                Text("OpenDeezer")
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(DZ.textPri)

                if app.busy {
                    ProgressView("Logging in…").tint(DZ.accent)
                } else {
                    Button { app.beginWebLogin() } label: {
                        Label("Log in with Deezer", systemImage: "person.crop.circle")
                            .frame(minWidth: 240)
                    }
                    .buttonStyle(.borderedProminent).tint(DZ.accent).controlSize(.large)

                    Button(showManual ? "Hide manual ARL" : "Enter ARL manually") {
                        withAnimation { showManual.toggle() }
                    }
                    .font(.callout).foregroundStyle(DZ.textSec)

                    if showManual {
                        VStack(spacing: 8) {
                            SecureField("Paste your ARL cookie", text: $app.manualARL)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 320)
                            Button("Sign in") { app.loginWithManualARL() }
                                .buttonStyle(.bordered).tint(DZ.accent)
                                .disabled(app.manualARL.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .transition(.opacity)
                    }

                    if let e = app.loginError {
                        Text(e).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }
            .padding(32)
        }
    }
}

// MARK: - Free Account Gate

struct FreeAccountBlockedView: View {
    @EnvironmentObject var app: AppState

    private var offer: String {
        let o = app.account?.offer ?? ""
        return o.isEmpty ? "Deezer Free" : o
    }

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill").font(.system(size: 52)).foregroundStyle(DZ.accent)
                Text("OpenDeezer")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(DZ.textPri)
                Text("Sorry — your account isn't supported")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(DZ.textPri)
                    .multilineTextAlignment(.center)
                Text("OpenDeezer needs Deezer Premium to stream on-demand. Your account: \(offer). Subscribe at deezer.com, then sign in again.")
                    .font(.body).foregroundStyle(DZ.textSec)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                Button { app.beginWebLogin() } label: {
                    Label("Log in with a different account", systemImage: "person.crop.circle")
                }
                .buttonStyle(.borderedProminent).tint(DZ.accent)
            }
            .padding(24)
        }
    }
}

// MARK: - Shared UI Atoms

struct ExplicitBadge: View {
    var body: some View {
        Text("E")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(DZ.textSec)
            .frame(width: 14, height: 14)
            .background(DZ.textSec.opacity(0.22), in: RoundedRectangle(cornerRadius: 3))
            .accessibilityLabel("Explicit")
    }
}

struct Artwork: View {
    let url: String
    let size: CGFloat
    var radius: CGFloat = 4

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            default:
                Rectangle().fill(DZ.panelBG)
                    .overlay(Image(systemName: "music.note").foregroundStyle(DZ.textSec))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var app: AppState
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                LikedTab()
                    .tabItem { Label("Liked", systemImage: "heart.fill") }.tag(0)
                SearchTab()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(1)
                PlaylistsTab()
                    .tabItem { Label("Playlists", systemImage: "music.note.list") }.tag(2)
                ChartsTab()
                    .tabItem { Label("Charts", systemImage: "chart.bar.fill") }.tag(3)
                FlowTab()
                    .tabItem { Label("Flow", systemImage: "infinity") }.tag(4)
                PodcastsTab()
                    .tabItem { Label("Podcasts", systemImage: "mic.fill") }.tag(5)
                SettingsTab()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(6)
            }
            .tint(DZ.accent)

            if app.current != nil {
                VStack(spacing: 0) {
                    MiniPlayerBar()
                    // Spacer to clear the tab bar (safe area handled by safeAreaInset)
                    Color.clear.frame(height: 49)
                }
            }
        }
        .sheet(isPresented: $app.showNowPlaying) {
            NowPlayingScreen()
                .environmentObject(app)
        }
    }
}

// MARK: - Individual Tabs

struct LikedTab: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        NavigationStack {
            TrackListView(
                tracks: app.tracks,
                title: "Liked Songs",
                artwork: app.listArtwork,
                isLiked: true,
                heroSymbol: "heart.fill",
                subtitle: "\(app.tracks.count) songs"
            )
            .navigationTitle("Liked Songs")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { if app.tracks.isEmpty { app.loadFavorites() } }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { app.loadFavorites() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

struct SearchTab: View {
    var body: some View {
        NavigationStack {
            SearchView()
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct PlaylistsTab: View {
    @EnvironmentObject var app: AppState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            PlaylistGridView(playlists: app.playlists) { p in
                app.openPlaylist(p)
                path.append(p)
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Playlist.self) { p in
                TrackListView(
                    tracks: app.tracks,
                    title: p.name,
                    artwork: p.artworkUrl,
                    isLiked: false,
                    heroSymbol: "music.note.list",
                    subtitle: p.owner.isEmpty ? "Playlist" : "Playlist · \(p.owner)"
                )
                .navigationTitle(p.name)
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear { if app.playlists.isEmpty { app.loadPlaylists() } }
        }
    }
}

struct ChartsTab: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        NavigationStack {
            ChartsView()
                .navigationTitle("Charts")
                .navigationBarTitleDisplayMode(.large)
                .onAppear { if app.tracks.isEmpty { app.loadCharts() } }
        }
    }
}

struct FlowTab: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        NavigationStack {
            TrackListView(
                tracks: app.tracks,
                title: "Flow",
                artwork: "",
                isLiked: true,
                heroSymbol: "infinity",
                subtitle: "Your personal soundtrack"
            )
            .navigationTitle("Flow")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { app.loadFlow() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

struct PodcastsTab: View {
    var body: some View {
        NavigationStack {
            PodcastsView()
                .navigationTitle("Podcasts")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
