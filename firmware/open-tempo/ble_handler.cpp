#include "ble_handler.h"

BleHandler::BleHandler(LedPlayer& player, PresetStore& store)
    : _player(player)
    , _store(store)
    , _server(nullptr)
    , _charCommand(nullptr)
    , _charUploadData(nullptr)
    , _charPresetMgmt(nullptr)
    , _charStatus(nullptr)
    , _connected(false)
    , _uploading(false)
    , _uploadPresetId(0)
    , _uploadFrameCount(0)
    , _uploadFps(0)
    , _uploadBuffer(nullptr)
    , _uploadBytesReceived(0)
    , _uploadBytesExpected(0)
    , _pendingCmd(0)
    , _pendingArg(0)
{
}

void BleHandler::begin() {
    BLEDevice::init(BLE_DEVICE_NAME);

    // Request a larger MTU so frame data chunks can be bigger.
    BLEDevice::setMTU(512);

    _server = BLEDevice::createServer();
    _server->setCallbacks(this);

    BLEService* service = _server->createService(BLEUUID(SERVICE_UUID), 20); // 20 handles

    // Command characteristic (write)
    _charCommand = service->createCharacteristic(
        BLEUUID(CHAR_COMMAND_UUID),
        BLECharacteristic::PROPERTY_WRITE
    );
    _charCommand->setCallbacks(this);

    // Upload data characteristic (write without response for throughput)
    _charUploadData = service->createCharacteristic(
        BLEUUID(CHAR_UPLOAD_DATA_UUID),
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    _charUploadData->setCallbacks(this);

    // Preset management characteristic (read + notify for list results)
    _charPresetMgmt = service->createCharacteristic(
        BLEUUID(CHAR_PRESET_MGMT_UUID),
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _charPresetMgmt->addDescriptor(new BLE2902());

    // Status characteristic (read + notify)
    _charStatus = service->createCharacteristic(
        BLEUUID(CHAR_STATUS_UUID),
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    _charStatus->addDescriptor(new BLE2902());

    service->start();

    BLEAdvertising* advertising = BLEDevice::getAdvertising();
    advertising->addServiceUUID(BLEUUID(SERVICE_UUID));
    advertising->setScanResponse(true);
    advertising->setMinPreferred(0x06);
    advertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("[BLE] Advertising started");
}

void BleHandler::update() {
    uint8_t cmd = _pendingCmd;
    if (cmd == 0) return;

    uint8_t arg = _pendingArg;
    _pendingCmd = 0;

    switch (cmd) {
        case CMD_PLAY:
            handlePlay(arg);
            break;
        case CMD_STOP:
            handleStop();
            break;
        case CMD_LIST_PRESETS:
            handleListPresets();
            break;
        case CMD_DELETE_PRESET:
            handleDeletePreset(arg);
            break;
        default:
            break;
    }
}

// --- BLE Server Callbacks ---

void BleHandler::onConnect(BLEServer* server) {
    _connected = true;
    Serial.println("[BLE] Client connected");
}

void BleHandler::onDisconnect(BLEServer* server) {
    _connected = false;
    Serial.println("[BLE] Client disconnected");
    // Restart advertising so the device can be found again.
    BLEDevice::startAdvertising();
}

// --- BLE Characteristic Callbacks ---

void BleHandler::onWrite(BLECharacteristic* characteristic) {
    std::string raw = characteristic->getValue();
    const uint8_t* data = (const uint8_t*)raw.data();
    size_t len = raw.length();

    if (len == 0) return;

    BLEUUID uuid = characteristic->getUUID();

    // Upload data characteristic - handle immediately (high throughput path).
    if (uuid.equals(BLEUUID(CHAR_UPLOAD_DATA_UUID))) {
        handleUploadData(data, len);
        return;
    }

    // Command characteristic.
    if (uuid.equals(BLEUUID(CHAR_COMMAND_UUID))) {
        uint8_t cmd = data[0];

        switch (cmd) {
            case CMD_PLAY:
                if (len >= 2) {
                    _pendingArg = data[1];
                    _pendingCmd = CMD_PLAY;
                }
                break;
            case CMD_STOP:
                _pendingCmd = CMD_STOP;
                break;
            case CMD_UPLOAD_START:
                // Handle inline since it sets up upload state.
                handleUploadStart(data, len);
                break;
            case CMD_LIST_PRESETS:
                _pendingCmd = CMD_LIST_PRESETS;
                break;
            case CMD_DELETE_PRESET:
                if (len >= 2) {
                    _pendingArg = data[1];
                    _pendingCmd = CMD_DELETE_PRESET;
                }
                break;
            default:
                Serial.printf("[BLE] Unknown command: 0x%02X\n", cmd);
                break;
        }
    }
}

// --- Command Handlers ---

void BleHandler::handlePlay(uint8_t presetId) {
    Serial.printf("[BLE] PLAY preset %u\n", presetId);

    if (_player.loadPreset(_store, presetId)) {
        _player.play();
        _store.saveLastPresetId(presetId);
        sendStatus(STATUS_PLAYING);
    } else {
        Serial.printf("[BLE] Failed to load preset %u\n", presetId);
        sendStatus(STATUS_ERROR);
    }
}

void BleHandler::handleStop() {
    Serial.println("[BLE] STOP");
    _player.stop();
    sendStatus(STATUS_STOPPED);
}

void BleHandler::handleUploadStart(const uint8_t* data, size_t len) {
    // Format: [CMD_UPLOAD_START, preset_id, frame_count_lo, frame_count_hi, fps]
    if (len < 5) {
        Serial.println("[BLE] UPLOAD_START: too short");
        sendStatus(STATUS_ERROR);
        return;
    }

    // Stop playback during upload.
    _player.stop();

    _uploadPresetId = data[1];
    _uploadFrameCount = data[2] | (data[3] << 8);
    _uploadFps = data[4];

    if (_uploadFrameCount == 0 || _uploadFrameCount > MAX_FRAMES) {
        Serial.printf("[BLE] UPLOAD_START: invalid frame count %u\n", _uploadFrameCount);
        sendStatus(STATUS_ERROR);
        return;
    }

    _uploadBytesExpected = (uint32_t)_uploadFrameCount * BYTES_PER_FRAME;
    _uploadBytesReceived = 0;

    // Allocate upload buffer.
    if (_uploadBuffer) {
        free(_uploadBuffer);
    }
    _uploadBuffer = (uint8_t*)malloc(_uploadBytesExpected);
    if (!_uploadBuffer) {
        Serial.printf("[BLE] UPLOAD_START: alloc failed (%lu bytes)\n",
                      (unsigned long)_uploadBytesExpected);
        sendStatus(STATUS_ERROR);
        return;
    }

    _uploading = true;
    Serial.printf("[BLE] UPLOAD_START: preset %u, %u frames @ %u fps, expecting %lu bytes\n",
                  _uploadPresetId, _uploadFrameCount, _uploadFps,
                  (unsigned long)_uploadBytesExpected);
    sendStatus(STATUS_OK);
}

void BleHandler::handleUploadData(const uint8_t* data, size_t len) {
    if (!_uploading || !_uploadBuffer) {
        Serial.println("[BLE] UPLOAD_DATA: not in upload mode");
        return;
    }

    // Clamp to remaining expected bytes.
    uint32_t remaining = _uploadBytesExpected - _uploadBytesReceived;
    size_t copyLen = (len > remaining) ? remaining : len;

    memcpy(_uploadBuffer + _uploadBytesReceived, data, copyLen);
    _uploadBytesReceived += copyLen;

    // Check if upload is complete.
    if (_uploadBytesReceived >= _uploadBytesExpected) {
        Serial.printf("[BLE] Upload complete (%lu bytes). Saving preset %u...\n",
                      (unsigned long)_uploadBytesReceived, _uploadPresetId);

        bool ok = _store.savePreset(_uploadPresetId, _uploadBuffer,
                                    _uploadFrameCount, _uploadFps);
        resetUpload();

        if (ok) {
            sendStatus(STATUS_UPLOAD_OK);
        } else {
            sendStatus(STATUS_ERROR);
        }
    }
}

void BleHandler::handleListPresets() {
    Serial.println("[BLE] LIST_PRESETS");

    uint8_t ids[MAX_PRESETS];
    uint8_t count = _store.listPresets(ids, MAX_PRESETS);

    // Send the list via the preset management characteristic.
    // Format: [count, id0, id1, id2, ...]
    uint8_t response[1 + count];
    response[0] = count;
    memcpy(response + 1, ids, count);

    _charPresetMgmt->setValue(response, 1 + count);
    _charPresetMgmt->notify();

    Serial.printf("[BLE] Listed %u presets\n", count);
}

void BleHandler::handleDeletePreset(uint8_t presetId) {
    Serial.printf("[BLE] DELETE_PRESET %u\n", presetId);

    if (_store.deletePreset(presetId)) {
        sendStatus(STATUS_OK);
    } else {
        sendStatus(STATUS_ERROR);
    }
}

// --- Helpers ---

void BleHandler::sendStatus(uint8_t code) {
    _charStatus->setValue(&code, 1);
    _charStatus->notify();
}

void BleHandler::sendStatus(const uint8_t* data, size_t len) {
    _charStatus->setValue(const_cast<uint8_t*>(data), len);
    _charStatus->notify();
}

void BleHandler::resetUpload() {
    _uploading = false;
    if (_uploadBuffer) {
        free(_uploadBuffer);
        _uploadBuffer = nullptr;
    }
    _uploadBytesReceived = 0;
    _uploadBytesExpected = 0;
}
