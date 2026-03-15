#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// --- Hardware ---
static const uint8_t LED_PIN = 13;
static const uint16_t NUM_PIXELS = 60;

// --- Playback ---
static const uint8_t DEFAULT_FPS = 60;
static const uint16_t MAX_FRAMES = 600;        // 10 seconds at 60 FPS
static const uint16_t BYTES_PER_FRAME = NUM_PIXELS; // 1 byte per pixel (white channel)

// --- Preset storage ---
static const uint16_t MAX_PRESETS = 200;
static const char* PRESET_DIR = "/presets";
static const char* LAST_PRESET_PATH = "/last_preset";

// --- BLE ---
static const char* BLE_DEVICE_NAME = "Open Tempo";

// Service
static const char* SERVICE_UUID              = "e0510001-7957-4a42-a8c5-81b994f80000";

// Characteristics
static const char* CHAR_COMMAND_UUID         = "e0510002-7957-4a42-a8c5-81b994f80000";
static const char* CHAR_UPLOAD_DATA_UUID     = "e0510003-7957-4a42-a8c5-81b994f80000";
static const char* CHAR_PRESET_MGMT_UUID     = "e0510004-7957-4a42-a8c5-81b994f80000";
static const char* CHAR_STATUS_UUID          = "e0510005-7957-4a42-a8c5-81b994f80000";

// --- BLE Commands (written to CHAR_COMMAND) ---
static const uint8_t CMD_PLAY           = 0x01; // + uint8_t preset_id
static const uint8_t CMD_STOP           = 0x02;
static const uint8_t CMD_UPLOAD_START   = 0x03; // + uint8_t preset_id, uint16_t frame_count, uint8_t fps
static const uint8_t CMD_UPLOAD_DATA    = 0x04; // + raw frame bytes (chunked)
static const uint8_t CMD_LIST_PRESETS   = 0x05;
static const uint8_t CMD_DELETE_PRESET  = 0x06; // + uint8_t preset_id

// --- BLE Status codes (notified on CHAR_STATUS) ---
static const uint8_t STATUS_OK          = 0x00;
static const uint8_t STATUS_PLAYING     = 0x01;
static const uint8_t STATUS_STOPPED     = 0x02;
static const uint8_t STATUS_UPLOAD_OK   = 0x03;
static const uint8_t STATUS_ERROR       = 0xFF;

#endif
