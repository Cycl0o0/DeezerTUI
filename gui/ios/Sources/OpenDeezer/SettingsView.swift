import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var updates: UpdateStore
    @StateObject private var hosts = RemoteHostStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var quality = AudioPrefs.quality
    @State private var gapless = AudioPrefs.gapless
    @State private var replayGain = AudioPrefs.replayGain
    @State private var crossfadeMs = Double(AudioPrefs.crossfadeMs)

    @State private var remoteInfo: WebRemoteInfo?
    @State private var qrImage: UIImage?
    @State private var connectInfo: ConnectHostInfo?

    private let qualities = [
        (0, "Normal", "MP3 · 128 kbps"),
        (1, "High", "MP3 · 320 kbps"),
        (2, "HiFi", "HiFi · FLAC"),
    ]

    var body: some View {
        NavigationStack {
            List {
                if let account = session.account {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name).font(.headline)
                                Text(account.offer).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Section("Audio Quality") {
                    ForEach(qualities, id: \.0) { level, name, detail in
                        Button {
                            quality = level
                            AudioPrefs.quality = level
                            Engine.setQuality(level)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(name).foregroundStyle(.primary)
                                    Text(detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if quality == level {
                                    Image(systemName: "checkmark").foregroundStyle(Palette.accent)
                                }
                            }
                        }
                    }
                }

                Section("Playback") {
                    Toggle("Gapless Playback", isOn: $gapless)
                        .onChange(of: gapless) { _, value in AudioPrefs.gapless = value; Engine.setGapless(value) }
                    Toggle("ReplayGain", isOn: $replayGain)
                        .onChange(of: replayGain) { _, value in AudioPrefs.replayGain = value; Engine.setReplayGain(value) }
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Crossfade")
                            Spacer()
                            Text(crossfadeMs == 0 ? "Off" : "\(Int(crossfadeMs / 1000))s")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $crossfadeMs, in: 0...12000, step: 1000)
                            .tint(Palette.accent)
                            .onChange(of: crossfadeMs) { _, value in AudioPrefs.crossfadeMs = Int(value); Engine.setCrossfadeMS(Int(value)) }
                    }
                }

                Section {
                    Toggle("OpenDeezer Connect", isOn: $hosts.connectHostEnabled)
                        .onChange(of: hosts.connectHostEnabled) { _, _ in
                            Task { await refreshConnect() }
                        }
                    if hosts.connectHostEnabled, let info = connectInfo, info.enabled {
                        HStack {
                            Label("Discoverable as", systemImage: "dot.radiowaves.left.and.right")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(info.name.isEmpty ? info.addr : info.name)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Text(info.addr)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("OpenDeezer Connect")
                } footer: {
                    Text("Let your other OpenDeezer devices (same Deezer account) find this iPhone and control its playback over the local network.")
                }

                Section {
                    Toggle("Phone Remote", isOn: $hosts.phoneRemoteEnabled)
                        .onChange(of: hosts.phoneRemoteEnabled) { _, _ in
                            Task { await refreshRemote() }
                        }
                    if hosts.phoneRemoteEnabled, let info = remoteInfo, info.enabled {
                        VStack(spacing: 10) {
                            if let qrImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 160, height: 160)
                            }
                            Text(info.code)
                                .font(.title3.monospaced().weight(.bold))
                            Text(info.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Phone Remote")
                } footer: {
                    Text("Control playback from a browser on the same network — scan the QR or open the URL.")
                }

                Section {
                    Button {
                        Task { await updates.checkNow() }
                    } label: {
                        HStack {
                            Text("Check for Updates")
                            Spacer()
                            if updates.isChecking {
                                ProgressView()
                            } else if let info = updates.info {
                                Text(info.hasUpdate ? "\(info.latest) available" : "Up to date")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let info = updates.info, info.hasUpdate {
                        Button("Download \(info.latest)") {
                            if let url = URL(string: info.url) { UIApplication.shared.open(url) }
                        }
                    }
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        session.logout()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await refreshRemote()
                await refreshConnect()
            }
        }
    }

    private func refreshRemote() async {
        let info = await Engine.webRemoteInfo()
        remoteInfo = info
        if let data = await Engine.webRemoteQRPNG(), let image = UIImage(data: data) {
            qrImage = image
        } else {
            qrImage = nil
        }
    }

    private func refreshConnect() async {
        connectInfo = await Engine.connectHostInfo()
    }
}
