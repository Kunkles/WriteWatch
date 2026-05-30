# Tally Light Firmware

HTTP tally bridge for SmallHD monitors. Receives HTTP commands from WriteWatch (or any HTTP client) and triggers GPI tally via optocoupler. Built on the Waveshare ESP32-S3-ETH with W5500 SPI Ethernet and WiFi fallback.

---

## Hardware

| Component | Value |
| :--- | :--- |
| Board | Waveshare ESP32-S3-ETH |
| Ethernet chip | W5500 (SPI, internally wired) |
| Tally output pin | GPIO18 (configurable in sketch) |
| Test button pin | GPIO3 |
| Optocoupler | NOYITO 1-channel PC817 module |
| ESP32 Arduino core | v3.x required |
| Board selection in IDE | ESP32S3 Dev Module |

### W5500 SPI Pin Mapping

On the Waveshare ESP32-S3-ETH these are internally wired — listed for reference only.

| GPIO | W5500 Function |
| :--- | :--- |
| GPIO9 | RST |
| GPIO10 | INT |
| GPIO11 | MOSI |
| GPIO12 | MISO |
| GPIO13 | CLK |
| GPIO14 | CS |

---

## Wiring

See [`docs/wiring.md`](docs/wiring.md) for full diagrams.

### ESP32 → Optocoupler (input side)

| Optocoupler | ESP32 |
| :--- | :--- |
| `+` (anode) | GPIO18 |
| `-` (cathode) | GND |

No current-limiting resistor needed — the NOYITO PC817 module has one built in.

### Optocoupler → SmallHD RJ45 (output side)

| Optocoupler | SmallHD RJ45 |
| :--- | :--- |
| `VCC` | 3.3V (ESP32) |
| `OUT` | Pin 7 (GPI active — OLED 22) |
| `GND` | Pin 8 (GPI ground) |

> **Use a screw terminal RJ45 breakout** on the SmallHD end (e.g. [Poyiccot RJ45 screw terminal](https://www.amazon.com/dp/B07WKKVZRF)). Direct bare-wire insertion with cut Ethernet cable is unreliable — 24AWG solid-core conductors make poor contact in open terminals.

---

## SmallHD Setup

See [`docs/smallhd_setup.md`](docs/smallhd_setup.md) for full setup instructions.

### OLED 22 (verified)

Requires PageOS 6.x or later.

| Setting | Value |
| :--- | :--- |
| GPI Function | Tally Indicator |
| Polarity | Active High |
| GPI Pin | **Pin 7** (not Pin 1) |

> Pin 1 does not work for tally on the OLED 22 — use Pin 7. Verified on hardware running PageOS 6.3.1.

**Logic:** open circuit = tally ON, contact closure = tally OFF. This is why the firmware uses `HIGH` to activate — it opens the optocoupler output and turns the tally on.

---

## Flashing

1. Open `tally_light.ino` in Arduino IDE
2. Set board to **ESP32S3 Dev Module**, ESP32 Arduino core v3.x
3. Tools → **Erase All Flash Before Sketch Upload → Enabled** (clean state on first flash)
4. Flash

All configuration is done through the browser after first flash — no per-unit sketch changes needed.

---

## Configuration

After flashing, open a browser to `http://tally-light.local/` (or the IP shown in the serial monitor).

| Setting | Notes |
| :--- | :--- |
| Device Hostname | Unique name per unit — e.g. `tally-cam1`. Becomes the `.local` mDNS address. |
| IP Mode | DHCP or Static. Static reveals IP / Gateway / Subnet / DNS fields. |
| WiFi SSID & Password | Fallback if Ethernet is not connected. |
| Tally Pin | GPIO pin for tally output. Default GPIO18; GPIO15 is a confirmed working substitute if 18 is damaged. |

Hit **Save & Reboot** — all settings persist in flash across reboots and reflashes.

### Deploying Multiple Units

1. Flash all units with the same firmware (no per-unit changes)
2. Connect each unit, open `http://tally-light.local/`
3. Set a unique hostname per unit (`tally-cam1`, `tally-cam2`, etc.)
4. Assign a static IP to each unit for reliable operation on managed networks
5. Use IP addresses in WriteWatch and Companion — `.local` mDNS can be unreliable on managed or VLAN'd networks

### Factory Reset

Open the web portal and click **Reset to Defaults**, or enable **Erase All Flash Before Sketch Upload** in Arduino IDE before reflashing.

---

## HTTP API

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/` | GET | Web config portal |
| `/tally/on` | GET | Activate tally (GPIO HIGH) |
| `/tally/off` | GET | Deactivate tally (GPIO LOW) |
| `/tally/test` | GET | 1-second tally pulse |
| `/status` | GET | Returns version, IP, interface, IP mode, tally state |
| `/config` | GET / POST | Config portal |
| `/reset` | POST | Clear all settings and reboot |

---

## Bitfocus Companion

Use **Generic: HTTP GET** action with static IPs.

| Button | URL |
| :--- | :--- |
| Record ON | `http://<device-ip>/tally/on` |
| Record OFF | `http://<device-ip>/tally/off` |
| Test | `http://<device-ip>/tally/test` |

---

## Known Issues

- mDNS (`.local`) resolution varies by network — always record the IP as a fallback
- With both Ethernet and WiFi active, mDNS can be inconsistent about which interface it advertises on
- GPI pin and polarity differ across SmallHD models — bench test each model before production deployment
