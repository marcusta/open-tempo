#ifndef PRESET_STORE_H
#define PRESET_STORE_H

#include <Arduino.h>
#include "config.h"

struct PresetHeader {
    uint16_t frameCount;
    uint8_t fps;
};

class PresetStore {
public:
    bool begin();

    // Save a complete preset to flash.
    bool savePreset(uint8_t id, const uint8_t* frameData, uint16_t frameCount, uint8_t fps);

    // Load preset header only (to get frame count / fps without loading all data).
    bool loadPresetHeader(uint8_t id, PresetHeader& header);

    // Load full preset frame data into the provided buffer.
    // Buffer must be at least header.frameCount * BYTES_PER_FRAME bytes.
    bool loadPresetData(uint8_t id, uint8_t* buffer, uint16_t bufferSize);

    // Delete a preset.
    bool deletePreset(uint8_t id);

    // List all stored preset IDs. Returns count, fills ids array (caller allocates).
    uint8_t listPresets(uint8_t* ids, uint8_t maxCount);

    // Remember last played preset so it auto-plays on boot.
    bool saveLastPresetId(uint8_t id);
    bool loadLastPresetId(uint8_t& id);

private:
    String presetPath(uint8_t id);
};

#endif
