#include "preset_store.h"
#include <LittleFS.h>

bool PresetStore::begin() {
    if (!LittleFS.begin(true)) { // true = format on first use
        Serial.println("[PresetStore] LittleFS mount failed");
        return false;
    }
    // Ensure preset directory exists.
    if (!LittleFS.exists(PRESET_DIR)) {
        LittleFS.mkdir(PRESET_DIR);
    }
    Serial.println("[PresetStore] Ready");
    return true;
}

String PresetStore::presetPath(uint8_t id) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%s/%03u.bin", PRESET_DIR, id);
    return String(buf);
}

bool PresetStore::savePreset(uint8_t id, const uint8_t* frameData, uint16_t frameCount, uint8_t fps) {
    String path = presetPath(id);
    File f = LittleFS.open(path, "w");
    if (!f) {
        Serial.printf("[PresetStore] Failed to open %s for writing\n", path.c_str());
        return false;
    }

    // Write header: frameCount (2 bytes LE) + fps (1 byte).
    uint8_t header[3];
    header[0] = frameCount & 0xFF;
    header[1] = (frameCount >> 8) & 0xFF;
    header[2] = fps;
    f.write(header, 3);

    // Write frame data.
    uint32_t dataSize = (uint32_t)frameCount * BYTES_PER_FRAME;
    f.write(frameData, dataSize);
    f.close();

    Serial.printf("[PresetStore] Saved preset %u (%u frames, %u fps, %lu bytes)\n",
                  id, frameCount, fps, (unsigned long)(dataSize + 3));
    return true;
}

bool PresetStore::loadPresetHeader(uint8_t id, PresetHeader& header) {
    String path = presetPath(id);
    File f = LittleFS.open(path, "r");
    if (!f) {
        return false;
    }
    uint8_t buf[3];
    if (f.read(buf, 3) != 3) {
        f.close();
        return false;
    }
    f.close();

    header.frameCount = buf[0] | (buf[1] << 8);
    header.fps = buf[2];
    return true;
}

bool PresetStore::loadPresetData(uint8_t id, uint8_t* buffer, uint16_t bufferSize) {
    String path = presetPath(id);
    File f = LittleFS.open(path, "r");
    if (!f) {
        Serial.printf("[PresetStore] Preset %u not found\n", id);
        return false;
    }

    // Read header first.
    uint8_t hdr[3];
    if (f.read(hdr, 3) != 3) {
        f.close();
        return false;
    }
    uint16_t frameCount = hdr[0] | (hdr[1] << 8);
    uint32_t dataSize = (uint32_t)frameCount * BYTES_PER_FRAME;

    if (dataSize > bufferSize) {
        Serial.printf("[PresetStore] Buffer too small (%u < %lu)\n", bufferSize, (unsigned long)dataSize);
        f.close();
        return false;
    }

    size_t bytesRead = f.read(buffer, dataSize);
    f.close();

    if (bytesRead != dataSize) {
        Serial.printf("[PresetStore] Short read: %u of %lu\n", (unsigned)bytesRead, (unsigned long)dataSize);
        return false;
    }

    Serial.printf("[PresetStore] Loaded preset %u (%u frames)\n", id, frameCount);
    return true;
}

bool PresetStore::deletePreset(uint8_t id) {
    String path = presetPath(id);
    if (!LittleFS.exists(path)) {
        return false;
    }
    LittleFS.remove(path);
    Serial.printf("[PresetStore] Deleted preset %u\n", id);
    return true;
}

uint8_t PresetStore::listPresets(uint8_t* ids, uint8_t maxCount) {
    File root = LittleFS.open(PRESET_DIR);
    if (!root || !root.isDirectory()) {
        return 0;
    }
    uint8_t count = 0;
    File entry = root.openNextFile();
    while (entry && count < maxCount) {
        String name = entry.name();
        // Files are named "NNN.bin". Parse the ID.
        int dotPos = name.lastIndexOf('.');
        if (dotPos > 0) {
            String idStr = name.substring(0, dotPos);
            // Handle paths that include directory prefix.
            int slashPos = idStr.lastIndexOf('/');
            if (slashPos >= 0) {
                idStr = idStr.substring(slashPos + 1);
            }
            uint8_t id = (uint8_t)idStr.toInt();
            ids[count++] = id;
        }
        entry = root.openNextFile();
    }
    return count;
}

bool PresetStore::saveLastPresetId(uint8_t id) {
    File f = LittleFS.open(LAST_PRESET_PATH, "w");
    if (!f) return false;
    f.write(id);
    f.close();
    return true;
}

bool PresetStore::loadLastPresetId(uint8_t& id) {
    File f = LittleFS.open(LAST_PRESET_PATH, "r");
    if (!f) return false;
    int val = f.read();
    f.close();
    if (val < 0) return false;
    id = (uint8_t)val;
    return true;
}
