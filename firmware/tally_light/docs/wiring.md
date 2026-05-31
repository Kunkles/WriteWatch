# Wiring Reference

## ESP32 to Optocoupler

| Optocoupler Pin | ESP32 Pin |
| :--- | :--- |
| `+` (input anode) | GPIO18 (TALLY_PIN) |
| `-` (input cathode) | GND |

The optocoupler input side is driven directly from the GPIO pin. No current-limiting resistor is needed for the NOYITO PC817 module as it has one built in.

---

## Optocoupler to SmallHD GPI RJ45 Port

Connect to the **GPI RJ45 port** on the SmallHD monitor (not the Ethernet port).

| Optocoupler Pin | SmallHD GPI RJ45 Pin |
| :--- | :--- |
| `VCC` | — (leave disconnected) |
| `OUT` | Pin 1 (GPI active) |
| `GND` | Pin 5 (GPI ground) |

---

## W5500 Ethernet Module to ESP32-S3

On the Waveshare ESP32-S3-ETH these are internally wired. Listed here for reference:

| W5500 | GPIO |
| :--- | :--- |
| RST | GPIO9 |
| INT | GPIO10 |
| MOSI | GPIO11 |
| MISO | GPIO12 |
| CLK | GPIO13 |
| CS | GPIO14 |

---

## Test Button

| Button Pin | ESP32 Pin |
| :--- | :--- |
| One side | GPIO3 |
| Other side | GND |

GPIO3 is configured with `INPUT_PULLUP`. Press triggers a 1-second tally test pulse.

---

## Notes

- If GPIO18 is damaged, change `TALLY_PIN` to another free GPIO (GPIO15 confirmed working substitute)
- Use a [screw terminal RJ45 breakout](https://www.amazon.com/dp/B07WKKVZRF) on the SmallHD end — direct bare-wire connections with cut Ethernet cable are unreliable
- Keep the optocoupler output wires short to avoid noise pickup
