# Open Tempo - ESP32 Firmware

Firmware for the Open Tempo putting tempo trainer. An ESP32 drives an SK6812 RGBW LED strip, playing back pre-rendered frame sequences received from an iOS app over BLE.

## Hardware

- ESP32 NodeMCU dev board
- SK6812 RGBW LED strip (60 LEDs/m, 5V) - data pin connected to GPIO 13
- 5V power supply rated for the strip (60 LEDs x 80mA max = 4.8A worst case, but white-only usage draws much less)

## Arduino IDE Setup

1. **Add ESP32 board support:**
   - File > Preferences > Additional Board Manager URLs, add:
     `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Tools > Board > Boards Manager, search "esp32", install **esp32 by Espressif Systems**

2. **Install libraries** (Tools > Manage Libraries):
   - **Adafruit NeoPixel** (for SK6812 RGBW support)
   - The ESP32 BLE and LittleFS libraries are bundled with the ESP32 board package.

3. **Board settings:**
   - Board: "ESP32 Dev Module" (or "NodeMCU-32S")
   - Partition Scheme: "Default 4MB with spiffs" (LittleFS uses the same partition)
   - Flash Size: 4MB
   - Upload Speed: 921600

4. **Open** `firmware/open-tempo/open-tempo.ino` and upload.

## Pin Wiring

| Signal   | ESP32 Pin | LED Strip |
|----------|-----------|-----------|
| Data     | GPIO 13   | DIN       |
| Power    | -         | 5V (external PSU) |
| Ground   | GND       | GND (shared with PSU) |

## BLE Protocol

The device advertises as "Open Tempo" with service UUID `e0510001-7957-4a42-a8c5-81b994f80000`.

### Characteristics

| Name         | UUID     | Properties         | Purpose                        |
|--------------|----------|--------------------|--------------------------------|
| Command      | ...0002  | Write              | Send commands                  |
| Upload Data  | ...0003  | Write / Write NR   | Stream frame data chunks       |
| Preset Mgmt  | ...0004  | Read / Notify      | Receive preset list            |
| Status       | ...0005  | Read / Notify      | Receive status/error codes     |

### Commands (write to Command characteristic)

| Command        | Byte format                                         |
|----------------|-----------------------------------------------------|
| PLAY           | `[0x01, preset_id]`                                 |
| STOP           | `[0x02]`                                            |
| UPLOAD_START   | `[0x03, preset_id, frame_count_lo, frame_count_hi, fps]` |
| UPLOAD_DATA    | Raw frame bytes (write to Upload Data characteristic) |
| LIST_PRESETS   | `[0x05]`                                            |
| DELETE_PRESET  | `[0x06, preset_id]`                                 |

### Frame Format

Each frame is 60 bytes (one byte per pixel, white intensity 0-255). A typical 5-second sequence at 60 FPS is 300 frames = 18,000 bytes. The iOS app sends UPLOAD_START, then streams raw frame data in MTU-sized chunks to the Upload Data characteristic.

### Status Codes (notified on Status characteristic)

| Code | Meaning       |
|------|---------------|
| 0x00 | OK            |
| 0x01 | Playing       |
| 0x02 | Stopped       |
| 0x03 | Upload OK     |
| 0xFF | Error         |
