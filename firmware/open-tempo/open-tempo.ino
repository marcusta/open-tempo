// Open Tempo - DIY Putting Tempo Trainer
// ESP32 firmware for BLE-controlled SK6812 RGBW LED strip playback.

#include "config.h"
#include "preset_store.h"
#include "led_player.h"
#include "ble_handler.h"

PresetStore presetStore;
LedPlayer   ledPlayer;
BleHandler  bleHandler(ledPlayer, presetStore);

void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n=== Open Tempo ===");

    // Initialize flash storage.
    if (!presetStore.begin()) {
        Serial.println("FATAL: PresetStore init failed");
        while (true) { delay(1000); }
    }

    // Initialize LED strip.
    ledPlayer.begin();

    // Initialize BLE.
    bleHandler.begin();

    // Auto-play last used preset if available.
    uint8_t lastId;
    if (presetStore.loadLastPresetId(lastId)) {
        Serial.printf("Auto-playing last preset: %u\n", lastId);
        if (ledPlayer.loadPreset(presetStore, lastId)) {
            ledPlayer.play();
        }
    } else {
        Serial.println("No last preset saved");
    }

    Serial.println("Setup complete");
}

void loop() {
    // Drive frame playback (timing-critical).
    ledPlayer.update();

    // Process any pending BLE commands.
    bleHandler.update();
}
