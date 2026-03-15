#include "led_player.h"

LedPlayer::LedPlayer()
    : _strip(NUM_PIXELS, LED_PIN, NEO_GRBW + NEO_KHZ800)
    , _frameBuffer(nullptr)
    , _frameCount(0)
    , _fps(DEFAULT_FPS)
    , _frameDurationUs(1000000UL / DEFAULT_FPS)
    , _playing(false)
    , _currentFrame(0)
    , _lastFrameTimeUs(0)
{
}

void LedPlayer::begin() {
    _strip.begin();
    _strip.setBrightness(255);
    allOff();
    Serial.println("[LedPlayer] Ready");
}

bool LedPlayer::loadPreset(PresetStore& store, uint8_t presetId) {
    // Stop any current playback.
    stop();

    // Read the header to learn frame count and fps.
    PresetHeader header;
    if (!store.loadPresetHeader(presetId, header)) {
        Serial.printf("[LedPlayer] Preset %u header not found\n", presetId);
        return false;
    }

    if (header.frameCount == 0 || header.frameCount > MAX_FRAMES) {
        Serial.printf("[LedPlayer] Invalid frame count: %u\n", header.frameCount);
        return false;
    }

    // Allocate (or reallocate) frame buffer.
    uint32_t dataSize = (uint32_t)header.frameCount * BYTES_PER_FRAME;
    if (_frameBuffer) {
        free(_frameBuffer);
        _frameBuffer = nullptr;
    }
    _frameBuffer = (uint8_t*)malloc(dataSize);
    if (!_frameBuffer) {
        Serial.printf("[LedPlayer] Failed to allocate %lu bytes\n", (unsigned long)dataSize);
        _frameCount = 0;
        return false;
    }

    // Load frame data.
    if (!store.loadPresetData(presetId, _frameBuffer, dataSize)) {
        free(_frameBuffer);
        _frameBuffer = nullptr;
        _frameCount = 0;
        return false;
    }

    _frameCount = header.frameCount;
    _fps = header.fps > 0 ? header.fps : DEFAULT_FPS;
    _frameDurationUs = 1000000UL / _fps;

    Serial.printf("[LedPlayer] Loaded preset %u: %u frames @ %u fps (%lu us/frame)\n",
                  presetId, _frameCount, _fps, (unsigned long)_frameDurationUs);
    return true;
}

void LedPlayer::play() {
    if (!_frameBuffer || _frameCount == 0) {
        Serial.println("[LedPlayer] No preset loaded");
        return;
    }
    _currentFrame = 0;
    _playing = true;
    _lastFrameTimeUs = micros();
    showFrame(0);
    Serial.println("[LedPlayer] Playing");
}

void LedPlayer::stop() {
    _playing = false;
    _currentFrame = 0;
    allOff();
}

void LedPlayer::update() {
    if (!_playing) return;

    uint32_t now = micros();
    uint32_t elapsed = now - _lastFrameTimeUs;

    if (elapsed >= _frameDurationUs) {
        _currentFrame++;

        if (_currentFrame >= _frameCount) {
            // Sequence complete. Stop playback.
            stop();
            Serial.println("[LedPlayer] Playback complete");
            return;
        }

        // Advance the reference time by exactly one frame duration to avoid drift.
        _lastFrameTimeUs += _frameDurationUs;

        // If we fell behind by more than one full frame, re-sync to avoid a burst of
        // catch-up frames. This can happen if something blocks the loop briefly.
        if ((micros() - _lastFrameTimeUs) > _frameDurationUs) {
            _lastFrameTimeUs = micros();
        }

        showFrame(_currentFrame);
    }
}

void LedPlayer::showFrame(uint16_t frameIndex) {
    const uint8_t* frame = _frameBuffer + ((uint32_t)frameIndex * BYTES_PER_FRAME);
    for (uint16_t i = 0; i < NUM_PIXELS; i++) {
        uint8_t w = frame[i];
        // SK6812 RGBW: set only white channel.
        _strip.setPixelColor(i, _strip.Color(0, 0, 0, w));
    }
    _strip.show();
}

void LedPlayer::allOff() {
    _strip.clear();
    _strip.show();
}
