# SmallHD GPI Tally Setup

## OLED 22 (Verified)

PageOS 6.x or later required.

### User Functions menu

Before configuring GPI, disable press-and-hold editing:

**Menu → User Functions → Press-and-Hold to Edit → Off**

This must be off for GPI tally to work correctly in this configuration.

### GPI Settings

| Setting | Value |
| :--- | :--- |
| GPI Function | Tally Indicator |
| Polarity | Active Low |
| GPI Pin | **Pin 1** |

**Behavior:**
- GPI pin LOW = Tally ON
- GPI pin HIGH / open circuit = Tally OFF

**Signal chain:** `/tally/on` → GPIO HIGH → PC817 LED on → phototransistor conducts → GPI pin pulled LOW → tally ON.

---

## Other SmallHD Models

GPI pin assignment and polarity vary by model. Bench test each model before production deployment. Settings that work on the OLED 22 may not apply to other monitors in a mixed fleet.

---

## RJ45 Pinout Reference (T568B)

| Pin | Color | Used for tally |
| :--- | :--- | :--- |
| 1 | White/Orange | **GPI active (OLED 22)** |
| 2 | Orange | — |
| 3 | White/Green | — |
| 4 | Blue | Check monitor docs |
| 5 | White/Blue | Check monitor docs |
| 6 | Green | — |
| 7 | White/Brown | — |
| 8 | Brown | GPI ground |

> Use a screw terminal RJ45 breakout board for reliable connections. Bare Ethernet wire is 24AWG solid-core and makes poor contact when inserted directly into terminals.
