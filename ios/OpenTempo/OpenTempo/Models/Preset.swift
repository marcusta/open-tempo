import Foundation

/// A rendered animation preset that can be uploaded to the ESP32.
struct Preset: Identifiable, Codable {
    let id: UUID
    var name: String
    let parameters: PuttingParameters
    let fps: Double
    let frameCount: Int
    /// Flat array of frame data. Each frame is `LEDStrip.pixelCount` bytes.
    /// Total size = frameCount * pixelCount.
    let frameData: Data
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        parameters: PuttingParameters,
        fps: Double = AnimationConfig.fps,
        frameCount: Int,
        frameData: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parameters = parameters
        self.fps = fps
        self.frameCount = frameCount
        self.frameData = frameData
        self.createdAt = createdAt
    }

    /// Returns the frame at the given index as a `[UInt8]` array of length `pixelCount`.
    func frame(at index: Int) -> [UInt8] {
        guard index >= 0, index < frameCount else { return [UInt8](repeating: 0, count: LEDStrip.pixelCount) }
        let start = index * LEDStrip.pixelCount
        let end = start + LEDStrip.pixelCount
        return [UInt8](frameData[start..<end])
    }
}
