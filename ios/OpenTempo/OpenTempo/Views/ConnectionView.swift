import SwiftUI

/// BLE device scanning and connection UI.
struct ConnectionView: View {
    @ObservedObject var bleManager: BLEManager

    var body: some View {
        List {
            Section {
                connectionStatusRow
            }

            if bleManager.connectionState == .disconnected || bleManager.connectionState == .scanning {
                Section("Devices") {
                    if bleManager.isScanning && bleManager.discoveredDevices.isEmpty {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Scanning for Open Tempo devices...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(bleManager.discoveredDevices, id: \.identifier) { device in
                        Button {
                            bleManager.connect(to: device)
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text(device.name ?? "Unknown Device")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let error = bleManager.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Connection")
    }

    @ViewBuilder
    private var connectionStatusRow: some View {
        HStack {
            statusIcon
            VStack(alignment: .leading) {
                Text(statusTitle)
                    .font(.headline)
                if let name = bleManager.connectedDevice?.name {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusButton
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch bleManager.connectionState {
        case .disconnected:
            Image(systemName: "bolt.slash.circle")
                .foregroundStyle(.secondary)
                .font(.title2)
        case .scanning:
            ProgressView()
        case .connecting:
            ProgressView()
        case .connected, .uploading:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
        }
    }

    private var statusTitle: String {
        switch bleManager.connectionState {
        case .disconnected: "Disconnected"
        case .scanning: "Scanning..."
        case .connecting: "Connecting..."
        case .connected: "Connected"
        case .uploading: "Uploading..."
        }
    }

    @ViewBuilder
    private var statusButton: some View {
        switch bleManager.connectionState {
        case .disconnected:
            Button("Scan") {
                bleManager.startScanning()
            }
            .buttonStyle(.borderedProminent)
        case .scanning:
            Button("Stop") {
                bleManager.stopScanning()
            }
            .buttonStyle(.bordered)
        case .connecting:
            EmptyView()
        case .connected, .uploading:
            Button("Disconnect") {
                bleManager.disconnect()
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionView(bleManager: BLEManager())
    }
}
