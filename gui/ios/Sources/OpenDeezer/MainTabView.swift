import SwiftUI

/// Apple-Music-style shell: Home / Search / Library tabs with the now-playing
/// mini player docked above the tab bar. On iOS 26 it's the system
/// `tabViewBottomAccessory` (native Liquid-Glass dock that sits *above* the tab
/// bar and morphs with it); on 17-25 it's a floating glass pill via
/// `safeAreaInset`. Either way, tapping it opens the full Now Playing sheet.
struct MainTabView: View {
    @EnvironmentObject private var player: PlayerController
    @EnvironmentObject private var updates: UpdateStore

    private enum Tab { case home, search, library }
    @State private var selectedTab: Tab = .home
    @State private var showNowPlaying = false

    var body: some View {
        content
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: player.hasNowPlaying)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: updates.hasUpdate)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
            .task { updates.checkOnce() }
    }

    @ViewBuilder private var content: some View {
        if #available(iOS 26.0, *) {
            tabs
                .tabViewBottomAccessory {
                    if player.hasNowPlaying {
                        MiniPlayerView(accessory: true)
                            .onTapGesture { showNowPlaying = true }
                    }
                }
        } else {
            tabs
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if player.hasNowPlaying {
                        MiniPlayerView()
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                            .onTapGesture { showNowPlaying = true }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            NavigationStack { LibraryView() }
                .tabItem { Label("Library", systemImage: "music.note.list") }
                .tag(Tab.library)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            UpdateBanner()
        }
    }
}
