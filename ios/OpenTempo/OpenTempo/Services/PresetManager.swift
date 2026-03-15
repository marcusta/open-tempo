import Foundation

/// Manages presets locally (persisted to disk) and coordinates uploads to the device.
@MainActor
final class PresetManager: ObservableObject {

    @Published var presets: [Preset] = []
    @Published var activePresetId: UUID?

    private let storageURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        storageURL = docs.appendingPathComponent("presets.json")
        loadPresets()
    }

    // MARK: - CRUD

    /// Render and save a new preset from the given parameters.
    func createPreset(name: String, parameters: PuttingParameters) -> Preset {
        let result = AnimationRenderer.render(params: parameters)
        let preset = Preset(
            name: name,
            parameters: parameters,
            frameCount: result.frameCount,
            frameData: result.data
        )
        presets.append(preset)
        savePresets()
        return preset
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        if activePresetId == id { activePresetId = nil }
        savePresets()
    }

    func preset(for id: UUID) -> Preset? {
        presets.first { $0.id == id }
    }

    // MARK: - Upload

    /// Render, save locally, and upload to the connected device.
    func renderAndUpload(
        name: String,
        parameters: PuttingParameters,
        bleManager: BLEManager
    ) async throws -> Preset {
        let preset = createPreset(name: name, parameters: parameters)
        activePresetId = preset.id
        try await bleManager.uploadPreset(preset)
        return preset
    }

    // MARK: - Persistence

    private func savePresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save presets: \(error)")
        }
    }

    private func loadPresets() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            presets = try JSONDecoder().decode([Preset].self, from: data)
        } catch {
            print("Failed to load presets: \(error)")
        }
    }
}
