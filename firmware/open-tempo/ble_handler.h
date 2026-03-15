#ifndef BLE_HANDLER_H
#define BLE_HANDLER_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "config.h"
#include "led_player.h"
#include "preset_store.h"

class BleHandler : public BLEServerCallbacks,
                   public BLECharacteristicCallbacks {
public:
    BleHandler(LedPlayer& player, PresetStore& store);

    void begin();
    void update();  // Call from loop() to handle pending commands

    bool isConnected() const { return _connected; }

    // BLEServerCallbacks
    void onConnect(BLEServer* server) override;
    void onDisconnect(BLEServer* server) override;

    // BLECharacteristicCallbacks
    void onWrite(BLECharacteristic* characteristic) override;

private:
    LedPlayer& _player;
    PresetStore& _store;

    BLEServer* _server;
    BLECharacteristic* _charCommand;
    BLECharacteristic* _charUploadData;
    BLECharacteristic* _charPresetMgmt;
    BLECharacteristic* _charStatus;

    bool _connected;

    // Upload state
    bool _uploading;
    uint8_t _uploadPresetId;
    uint16_t _uploadFrameCount;
    uint8_t _uploadFps;
    uint8_t* _uploadBuffer;
    uint32_t _uploadBytesReceived;
    uint32_t _uploadBytesExpected;

    // Pending command (processed in update() to avoid doing heavy work inside BLE callback)
    volatile uint8_t _pendingCmd;
    uint8_t _pendingArg;

    void sendStatus(uint8_t code);
    void sendStatus(const uint8_t* data, size_t len);

    void handlePlay(uint8_t presetId);
    void handleStop();
    void handleUploadStart(const uint8_t* data, size_t len);
    void handleUploadData(const uint8_t* data, size_t len);
    void handleListPresets();
    void handleDeletePreset(uint8_t presetId);

    void resetUpload();
};

#endif
