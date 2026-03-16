import SwiftUI

/// Main view with settings, connection status, and play/stop controls.
struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var presetManager = PresetManager()
    @State private var parameters = PuttingParameters()
    @State private var isUploading = false
    @State private var showConnectionSheet = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LEDSimulatorView(parameters: parameters)
                    .background(.black)

                SettingsView(parameters: $parameters)

                controlBar
            }
            .navigationTitle("Open Tempo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    connectionButton
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                NavigationStack {
                    ConnectionView(bleManager: bleManager)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showConnectionSheet = false }
                            }
                        }
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Control bar

    @ViewBuilder
    private var controlBar: some View {
        VStack(spacing: 12) {
            if isUploading {
                ProgressView(value: bleManager.uploadProgress) {
                    Text("Uploading...")
                        .font(.caption)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button {
                    applyPreset()
                } label: {
                    Label("Apply", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isConnected || isUploading)

                Button {
                    playCurrentPreset()
                } label: {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!isConnected || isUploading || presetManager.activePresetId == nil)

                Button {
                    bleManager.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!isConnected || isUploading)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Connection button

    @ViewBuilder
    private var connectionButton: some View {
        Button {
            showConnectionSheet = true
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(isConnected ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Connected" : "Connect")
                    .font(.caption)
            }
        }
    }

    // MARK: - Logic

    private var isConnected: Bool {
        bleManager.connectionState == .connected
    }

    private func applyPreset() {
        isUploading = true
        Task {
            do {
                let preset = try await presetManager.renderAndUpload(
                    name: "Preset \(presetManager.presets.count + 1)",
                    parameters: parameters,
                    bleManager: bleManager
                )
                presetManager.activePresetId = preset.id
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isUploading = false
        }
    }

    private func playCurrentPreset() {
        guard let id = presetManager.activePresetId else { return }
        bleManager.play(presetId: id)
    }
}

#Preview {
    ContentView()
}
