import SwiftUI

struct DevicePickerView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DZ.windowBG.ignoresSafeArea()
                List {
                    Section {
                        deviceRow(
                            symbol: "iphone",
                            title: "This device",
                            subtitle: "Play here",
                            connected: !app.isConnectedRemote
                        ) {
                            app.disconnectDevice()
                        }
                    }

                    Section {
                        if app.devicesLoading {
                            HStack(spacing: 10) {
                                ProgressView().tint(DZ.accent)
                                Text("Looking for devices…")
                                    .font(.system(size: 13)).foregroundStyle(DZ.textSec)
                            }
                            .listRowBackground(Color.clear)
                        } else if app.devices.isEmpty {
                            Text("No devices found on your network.")
                                .font(.system(size: 13)).foregroundStyle(DZ.textSec)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(app.devices) { d in
                                deviceRow(
                                    symbol: d.symbol,
                                    title: d.name.isEmpty ? d.addr : d.name,
                                    subtitle: "\(d.typeLabel) · OpenDeezer \(d.version)",
                                    connected: d.addr == app.connectedDeviceAddr
                                ) {
                                    app.connectDevice(d)
                                }
                            }
                        }
                    } header: {
                        Text("Devices")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(DZ.textSec)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Connect to a Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { app.discoverDevices() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(app.devicesLoading)
                }
            }
        }
    }

    private func deviceRow(symbol: String, title: String, subtitle: String,
                           connected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(connected ? DZ.accent : DZ.textPri)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).foregroundStyle(connected ? DZ.accent : DZ.textPri).lineLimit(1)
                    Text(subtitle).font(.caption).foregroundStyle(DZ.textSec).lineLimit(1)
                }
                Spacer()
                if connected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(DZ.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}
