import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    @State private var webRemoteEnabled = false
    @State private var webRemoteCode = ""
    @State private var webRemoteURL = ""
    @State private var webRemoteQRImage: UIImage? = nil

    var body: some View {
        ZStack {
            DZ.windowBG.ignoresSafeArea()
            List {
                // Audio quality
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Audio Quality", systemImage: "waveform")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(DZ.textPri)
                        Picker("Quality", selection: Binding(
                            get: { app.settings.quality },
                            set: { app.setQuality($0) })) {
                            Text("Normal · MP3 128").tag(0)
                            Text("High · MP3 320").tag(1)
                            Text("HiFi · FLAC").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("HiFi streams lossless FLAC when available, otherwise falls back to MP3.")
                            .font(.caption).foregroundStyle(DZ.textSec)
                        if let note = app.qualityEntitlementNote {
                            Label(note, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(DZ.accentMag)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(DZ.panelBG)
                }

                // Gapless
                Section {
                    Toggle(isOn: Binding(
                        get: { app.settings.gapless },
                        set: { app.setGapless($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Gapless playback", systemImage: "forward.end.alt.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(DZ.textPri)
                            Text("No silence between tracks.")
                                .font(.caption).foregroundStyle(DZ.textSec)
                        }
                    }
                    .tint(DZ.accent)
                    .listRowBackground(DZ.panelBG)
                }

                // Crossfade
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Crossfade", systemImage: "wave.3.forward")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(DZ.textPri)
                        Picker("Crossfade", selection: Binding(
                            get: { app.settings.crossfadeMS },
                            set: { app.setCrossfadeMS($0) })) {
                            Text("Off").tag(0)
                            Text("3s").tag(3000)
                            Text("6s").tag(6000)
                            Text("12s").tag(12000)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("Fades the end of one track into the start of the next.")
                            .font(.caption).foregroundStyle(DZ.textSec)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(DZ.panelBG)
                }

                // ReplayGain
                Section {
                    Toggle(isOn: Binding(
                        get: { app.replayGain },
                        set: { app.setReplayGain($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Volume normalization", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(DZ.textPri)
                            Text("Evens out loudness between tracks (ReplayGain).")
                                .font(.caption).foregroundStyle(DZ.textSec)
                        }
                    }
                    .tint(DZ.accent)
                    .listRowBackground(DZ.panelBG)
                }

                // Phone Remote
                Section {
                    Toggle(isOn: Binding(
                        get: { webRemoteEnabled },
                        set: { on in
                            webRemoteEnabled = on
                            Engine.setWebRemoteEnabled(on)
                            if on { loadWebRemoteInfo() }
                            else { webRemoteCode = ""; webRemoteURL = ""; webRemoteQRImage = nil }
                        })) {
                        Label("Phone Remote", systemImage: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(DZ.textPri)
                    }
                    .tint(DZ.accent)
                    .listRowBackground(DZ.panelBG)

                    if webRemoteEnabled && !webRemoteCode.isEmpty {
                        VStack(spacing: 10) {
                            if let img = webRemoteQRImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: 160, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Text(webRemoteCode)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(DZ.textPri)
                            Text(webRemoteURL)
                                .font(.caption).foregroundStyle(DZ.textSec)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                        .listRowBackground(DZ.panelBG)
                    } else if webRemoteEnabled {
                        Text("Scan with another device (same Wi-Fi), then enter the code.")
                            .font(.caption).foregroundStyle(DZ.textSec)
                            .listRowBackground(DZ.panelBG)
                    }
                }

                // Account
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24)).foregroundStyle(DZ.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.account?.name ?? "OpenDeezer")
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(DZ.textPri)
                            Text(app.account?.offer ?? "—")
                                .font(.caption).foregroundStyle(DZ.textSec)
                        }
                        Spacer()
                        Button("Switch") { app.beginWebLogin() }
                            .buttonStyle(.bordered).tint(DZ.accent)
                    }
                    .listRowBackground(DZ.panelBG)
                }

                // About
                Section {
                    HStack {
                        Image(systemName: "heart.fill").foregroundStyle(DZ.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OpenDeezer")
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(DZ.textPri)
                            Text("by Cycl0o0 · AGPL-3.0")
                                .font(.caption).foregroundStyle(DZ.textSec)
                        }
                    }
                    .listRowBackground(DZ.panelBG)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .onAppear { loadWebRemoteInfo() }
    }

    private func loadWebRemoteInfo() {
        Task.detached {
            let info = Engine.webRemoteInfo()
            let qrData = (info?.enabled == true) ? Engine.webRemoteQRPNG() : nil
            let img: UIImage? = qrData.flatMap { UIImage(data: $0) }
            await MainActor.run {
                webRemoteEnabled = info?.enabled ?? false
                webRemoteCode = info?.code ?? ""
                webRemoteURL = info?.url ?? ""
                webRemoteQRImage = img
            }
        }
    }
}
