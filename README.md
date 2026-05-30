# WriteWatch v2

Real-time video transfer monitor for macOS with an integrated tally light controller.

---

## Download

**[WriteWatch-v2.0.0-beta.zip](https://github.com/Kunkles/WriteWatch/releases/tag/v2.0.0-beta)**

Unzip and drag `WriteWatch.app` to Applications.  
First launch: right-click → Open to bypass Gatekeeper (ad-hoc signed).

Requires **macOS 14** or later.

---

## Features

### Transfer monitoring
- Watches folders for actively growing video files (polls every 500 ms — works on SMB/NFS)
- Live write rate, peak rate, and elapsed time per file
- AVFoundation validation when a transfer completes
- Classic terminal view or Modern dashboard — switchable from the toolbar

### Tally tab
- Built-in tally light controller for **Waveshare ESP32-S3-ETH** units running the bundled firmware
- Bonjour discovery (`_tally._tcp`) — finds units on the local network automatically
- Gang mode — fire all units simultaneously with one button
- **Follow WriteWatch** — tallies turn on/off automatically as WriteWatch detects active writes
  - Manual override wins; clears automatically at the start of the next record cycle
  - Auto/Manual/Recording status shown inline

### Firmware
The ESP32-S3 firmware lives in [`firmware/tally_light/`](firmware/tally_light/tally_light.ino).  
Flash via Arduino IDE. See the [esp32-smallhd-tally-light](https://github.com/Kunkles/esp32-smallhd-tally-light) repo for hardware details.

---

## Building from source

Requires **Xcode 15** or later.

```
open "WriteWatch.xcodeproj"
```

Press **⌘R** to build and run.

---

## Architecture

| File | Purpose |
|------|---------|
| `WriteWatchApp.swift` | App entry point, window setup |
| `RootView.swift` | Top-level view — switches between Classic, Modern, and Tally modes |
| `MonitorViewModel.swift` | Folder list, global stats, persistence |
| `WatchedFolder.swift` | Per-folder watcher + tracker state |
| `FolderWatcher.swift` | 500 ms polling watcher (works on SMB/NFS) |
| `FileTracker.swift` | Core tracking logic — active/completed entries |
| `AVProbeService.swift` | AVFoundation media probe for file validation |
| `ContentView.swift` | Classic terminal UI |
| `ModernView.swift` | Modern sidebar/inspector UI |
| `AppTheme.swift` | Terminal colour palette |
| `Models.swift` | `FileEntry`, `FileStatus`, `ValidationState` |
| `Formatters.swift` | Size, rate, duration formatters |
| `BannerView.swift` | ASCII art banner |
| `TerminalComponents.swift` | Reusable terminal panels and table headers |
| `TransfersView.swift` | Active transfers table |
| `CompletedView.swift` | Completed files table |
| **Tally/** | |
| `TallyStore.swift` | Tally state, HTTP control, status polling, WriteWatch automation |
| `TallyUnit.swift` | Unit model (id, name, IP, isOn, isReachable) |
| `TallyDiscovery.swift` | Bonjour `_tally._tcp` scanner |
| `TallyRow.swift` | Inline-editable unit row |
| `TallyButtonStyle.swift` | Red/grey button style |
| `AddressHelper.swift` | Address sanitization (strips URLs, adds .local) |
| `Tally/Views/TallyView.swift` | Tally tab root view |
| `Tally/Views/DiscoveryView.swift` | Bonjour scan sheet |
| `Tally/Views/AddTallyView.swift` | Manual add sheet |

---

## Changelog

### v2.1.2-beta
- Fix: crash on macOS 15.7+ caused by ATS (App Transport Security) flagging
  plain HTTP connections to tally units as violations; added NSAllowsLocalNetworking
  so ATS treats local network HTTP as permitted

### v2.1.1-beta
- Fix: tally automation now works regardless of which tab is active — recording
  observer runs at the app level, not inside TallyView

### v2.1.0-beta
- Fix: tally no longer stays on when WriteWatch stops detecting active writes

### v2.0.0-beta
- Tally tab with Follow WriteWatch automation
- Firmware folder (`firmware/tally_light/`) for ESP32-S3 W5500
- Network entitlements for local HTTP and Bonjour discovery
- Icon-button toolbar switcher; Tally tab doesn't resize the window

### v1.8.4-beta
- Live status polling on config page
- Bonjour advertisement for network discovery
- Various stability fixes
