import SwiftUI

struct PlaylistGridView: View {
    @EnvironmentObject var app: AppState
    let playlists: [Playlist]
    let onOpen: (Playlist) -> Void
    @State private var createText = ""
    @State private var renameText = ""
    private let cols = [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)]

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: cols, spacing: 20) {
                    ForEach(playlists) { p in
                        PlaylistCard(playlist: p) { onOpen(p) }
                    }
                }
                .padding(16)
                .padding(.bottom, 12)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    createText = ""
                    app.showCreatePlaylist = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Playlist", isPresented: $app.showCreatePlaylist) {
            TextField("Playlist name", text: $createText)
            Button("Create") { app.createPlaylist(title: createText) }
                .disabled(createText.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: { Text("Name your new playlist.") }
        .alert("Rename Playlist",
               isPresented: Binding(
                get: { app.renameTarget != nil },
                set: { if !$0 { app.renameTarget = nil } })) {
            TextField("Playlist name", text: $renameText)
            Button("Save") {
                if let p = app.renameTarget { app.renamePlaylist(p, to: renameText) }
                app.renameTarget = nil
            }
            Button("Cancel", role: .cancel) { app.renameTarget = nil }
        } message: { Text("Enter a new name.") }
        .onChange(of: app.renameTarget) { p in renameText = p?.name ?? "" }
        .confirmationDialog(
            "Delete \u{201C}\(app.deleteTarget?.name ?? "")\u{201D}?",
            isPresented: Binding(
                get: { app.deleteTarget != nil },
                set: { if !$0 { app.deleteTarget = nil } }),
            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let p = app.deleteTarget { app.deletePlaylist(p) }
                app.deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { app.deleteTarget = nil }
        } message: { Text("This can't be undone.") }
    }
}

struct PlaylistCard: View {
    @EnvironmentObject var app: AppState
    let playlist: Playlist
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                Artwork(url: playlist.artworkUrl, size: 150, radius: 8)
                    .shadow(radius: 6, y: 4)
                Text(playlist.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DZ.textPri).lineLimit(1)
                Text("\(playlist.trackCount) tracks")
                    .font(.caption).foregroundStyle(DZ.textSec)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onOpen() } label: { Label("Open", systemImage: "play.fill") }
            Button { app.beginRename(playlist) } label: { Label("Rename…", systemImage: "pencil") }
            Button(role: .destructive) { app.deleteTarget = playlist } label: {
                Label("Delete…", systemImage: "trash")
            }
        }
    }
}
