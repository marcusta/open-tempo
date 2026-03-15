#ifndef LED_PLAYER_H
#define LED_PLAYER_H

#include <Arduino.h>
#include <Adafruit_NeoPixel.h>
#include "config.h"
#include "preset_store.h"

class LedPlayer {
public:
    LedPlayer();

    void begin();

    // Load a preset from the store into the playback buffer. Returns true on success.
    bool loadPreset(PresetStore& store, uint8_t presetId);

    // Start playback of the currently loaded preset.
    void play();

    // Stop playback and turn off LEDs.
    void stop();

    // Call from loop(). Drives frame output with precise timing.
    void update();

    bool isPlaying() const { return _playing; }
    bool isLoaded() const { return _frameCount > 0; }

    uint16_t frameCount() const { return _frameCount; }
    uint8_t fps() const { return _fps; }

private:
    Adafruit_NeoPixel _strip;

    uint8_t* _frameBuffer;      // Heap-allocated frame data
    uint16_t _frameCount;
    uint8_t _fps;
    uint32_t _frameDurationUs;   // Microseconds per frame

    volatile bool _playing;
    uint16_t _currentFrame;
    uint32_t _lastFrameTimeUs;

    void showFrame(uint16_t frameIndex);
    void allOff();
};

#endif
