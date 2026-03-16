import Foundation
import CoreBluetooth

enum BLE {
    static let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")

    // Characteristic UUIDs
    static let commandCharUUID = CBUUID(string: "12345678-1234-1234-1234-123456789001")
    static let dataCharUUID    = CBUUID(string: "12345678-1234-1234-1234-123456789002")
    static let statusCharUUID  = CBUUID(string: "12345678-1234-1234-1234-123456789003")

    // Command opcodes
    static let cmdPlay: UInt8         = 0x01
    static let cmdStop: UInt8         = 0x02
    static let cmdUploadStart: UInt8  = 0x03
    static let cmdUploadData: UInt8   = 0x04
    static let cmdListPresets: UInt8  = 0x05
    static let cmdDeletePreset: UInt8 = 0x06

    /// Maximum payload per BLE write (ATT MTU minus overhead).
    static let maxChunkSize = 180
}

enum LEDStrip {
    static let pixelCount = 60
    static let ledsPerMeter: Double = 60.0
    static let metersPerLED: Double = 1.0 / ledsPerMeter  // ~0.01667 m
}

enum AnimationConfig {
    static let fps: Double = 60.0
    static let frameDuration: Double = 1.0 / fps
    static let sequenceDuration: Double = 5.0
    static let totalFrames: Int = Int(sequenceDuration * fps) // 300
}

enum Defaults {
    static let backstrokeTime: Double = 0.6   // seconds
    static let downstrokeTime: Double = 0.3   // seconds
    static let ballSpeed: Double = 1.0        // m/s
    static let stimp: Double = 11.0            // stimpmeter reading in feet
    static let puttDistance: Double = 3.0      // meters

    /// Default smash factor calibration curve based on typical putter measurements.
    /// Short putts (~2 mph) have lower smash, longer putts (~10 mph) have higher smash.
    static let smashCalibration: [SmashCalibrationPoint] = [
        .init(ballSpeedMph: 2.0, smashFactor: 1.15),
        .init(ballSpeedMph: 4.0, smashFactor: 1.30),
        .init(ballSpeedMph: 6.0, smashFactor: 1.45),
        .init(ballSpeedMph: 10.0, smashFactor: 1.58),
    ]
}
