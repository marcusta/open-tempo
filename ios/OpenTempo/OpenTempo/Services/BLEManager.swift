import Foundation
import CoreBluetooth
import Combine

/// Manages BLE communication with the Open Tempo ESP32 device.
@MainActor
final class BLEManager: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var isScanning = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    @Published var uploadProgress: Double = 0.0

    enum ConnectionState: String {
        case disconnected
        case scanning
        case connecting
        case connected
        case uploading
    }

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var commandCharacteristic: CBCharacteristic?
    private var dataCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?

    private var uploadContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            lastError = "Bluetooth is not available"
            return
        }
        discoveredDevices.removeAll()
        isScanning = true
        connectionState = .scanning
        centralManager.scanForPeripherals(withServices: [BLE.serviceUUID], options: nil)
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }

    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionState = .connecting
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let device = connectedDevice {
            centralManager.cancelPeripheralConnection(device)
        }
        resetState()
    }

    /// Send a PLAY command for the given preset ID.
    func play(presetId: UUID) {
        var payload = Data([BLE.cmdPlay])
        payload.append(presetId.data)
        writeCommand(payload)
    }

    /// Send a STOP command.
    func stop() {
        writeCommand(Data([BLE.cmdStop]))
    }

    /// Upload a preset's frame data to the device.
    func uploadPreset(_ preset: Preset) async throws {
        guard connectionState == .connected, let dataCh = dataCharacteristic else {
            throw BLEError.notConnected
        }

        connectionState = .uploading
        uploadProgress = 0.0

        // 1. Send UPLOAD_START command: opcode + presetId(16) + frameCount(u16) + fps(u8)
        var startPayload = Data([BLE.cmdUploadStart])
        startPayload.append(preset.id.data)
        var frameCount = UInt16(preset.frameCount)
        startPayload.append(Data(bytes: &frameCount, count: 2))
        startPayload.append(UInt8(preset.fps))
        writeCommand(startPayload)

        // Small delay to let the device prepare
        try await Task.sleep(for: .milliseconds(100))

        // 2. Send frame data in chunks
        let data = preset.frameData
        let chunkSize = BLE.maxChunkSize
        let totalChunks = (data.count + chunkSize - 1) / chunkSize

        for chunkIndex in 0..<totalChunks {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, data.count)
            var chunk = Data([BLE.cmdUploadData])
            chunk.append(data[start..<end])

            guard let device = connectedDevice else { throw BLEError.notConnected }
            device.writeValue(chunk, for: dataCh, type: .withResponse)

            uploadProgress = Double(chunkIndex + 1) / Double(totalChunks)

            // Pace writes to avoid flooding the BLE link
            try await Task.sleep(for: .milliseconds(10))
        }

        connectionState = .connected
        uploadProgress = 1.0
    }

    /// Request the device to list stored presets.
    func listPresets() {
        writeCommand(Data([BLE.cmdListPresets]))
    }

    /// Delete a preset from the device.
    func deletePreset(id: UUID) {
        var payload = Data([BLE.cmdDeletePreset])
        payload.append(id.data)
        writeCommand(payload)
    }

    // MARK: - Helpers

    private func writeCommand(_ data: Data) {
        guard let device = connectedDevice, let ch = commandCharacteristic else {
            lastError = "Not connected"
            return
        }
        device.writeValue(data, for: ch, type: .withResponse)
    }

    private func resetState() {
        connectedDevice = nil
        commandCharacteristic = nil
        dataCharacteristic = nil
        statusCharacteristic = nil
        connectionState = .disconnected
        uploadProgress = 0.0
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state != .poweredOn {
                lastError = "Bluetooth state: \(central.state.rawValue)"
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedDevice = peripheral
            connectionState = .connected
            peripheral.discoverServices([BLE.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            lastError = error?.localizedDescription ?? "Failed to connect"
            connectionState = .disconnected
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            resetState()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard let services = peripheral.services else { return }
            for service in services where service.uuid == BLE.serviceUUID {
                peripheral.discoverCharacteristics(
                    [BLE.commandCharUUID, BLE.dataCharUUID, BLE.statusCharUUID],
                    for: service
                )
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            guard let characteristics = service.characteristics else { return }
            for ch in characteristics {
                switch ch.uuid {
                case BLE.commandCharUUID:
                    commandCharacteristic = ch
                case BLE.dataCharUUID:
                    dataCharacteristic = ch
                case BLE.statusCharUUID:
                    statusCharacteristic = ch
                    peripheral.setNotifyValue(true, for: ch)
                default:
                    break
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        // Handle status notifications from the device if needed in the future.
    }
}

// MARK: - UUID helpers

extension UUID {
    /// Convert UUID to 16-byte Data.
    var data: Data {
        withUnsafePointer(to: uuid) { ptr in
            Data(bytes: ptr, count: 16)
        }
    }
}

// MARK: - Errors

enum BLEError: LocalizedError {
    case notConnected
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to a device"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        }
    }
}
