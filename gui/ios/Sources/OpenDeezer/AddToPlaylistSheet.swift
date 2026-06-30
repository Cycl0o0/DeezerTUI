import SwiftUI

struct AddToPlaylistSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DZ.windowBG.ignoresSafeArea()
                VStack(spacing: 0) {
                    addToPlaylistHeader
                    Divider().overlay(DZ.hairline)
                    addToPlaylistContent
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var addToPlaylistHeader: some View {
        HStack(spacing: 12) {
            Artwork(url: app.addTarget?.artworkUrl ?? "", size: 40, radius: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add to Playlist")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(DZ.textPri)
                Text(app.addTarget?.name ?? "")
                    .font(.system(size: 12)).foregroundStyle(DZ.textSec).lineLimit(1)
            }
            Spacer()
            Button("Cancel") { app.showAddToPlaylist = false }
                .buttonStyle(.bordered).tint(DZ.accent)
        }
        .padding(16)
    }

    @ViewBuilder private var addToPlaylistContent: some View {
        if app.pickerLoading {
            VStack {
                Spacer()
                ProgressView().tint(DZ.accent)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    Button {
                        withAnimation { creating.toggle() }
                    } label: {
                        Label("New playlist…", systemImage: "plus.circle.fill")
                            .foregroundStyle(DZ.accent)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)

                    if creating {
                        HStack(spacing: 8) {
                            TextField("Playlist name", text: $newName)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(commitCreate)
                            Button("Create", action: commitCreate)
                                .buttonStyle(.borderedProminent).tint(DZ.accent)
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(app.pickerPlaylists) { p in
                        Button { app.addTargetTrack(toPlaylist: p.id) } label: {
                            HStack(spacing: 10) {
                                Artwork(url: p.artworkUrl, size: 36, radius: 4)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.name).foregroundStyle(DZ.textPri).lineLimit(1)
                                    Text("\(p.trackCount) tracks")
                                        .font(.caption).foregroundStyle(DZ.textSec)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Your Playlists")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(DZ.textSec)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func commitCreate() {
        app.createPlaylistAndAddTarget(title: newName)
        newName = ""
        creating = false
    }
}
