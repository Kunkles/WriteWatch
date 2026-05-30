# WriteWatch v2

Real-time video transfer monitor for macOS with an integrated tally light controller.  
Built by **32Thirteen Productions LLC**.

---

## Download

**[WriteWatch-v2.1.2-beta.zip](https://github.com/Kunkles/WriteWatch/releases/tag/v2.1.2-beta)**

Unzip and drag `WriteWatch.app` to Applications.  
First launch: right-click → Open to bypass Gatekeeper (ad-hoc signed).

Requires **macOS 14** or later.

---

## Features

### Transfer monitoring
- Watches folders for actively growing video files — polls every 500 ms, works on SMB/NFS
- Live write rate, peak rate, and elapsed time per file
- AVFoundation validation when a transfer completes (codec, duration, VFR detection)
- Duration accuracy coloring — compares wall-clock elapsed time to actual media length
- Disk space monitoring per watched volume with color-coded warnings
- Mid-write detection via lsof for files that were already recording when the folder was added
- Passive mode (default) — never spawns subprocesses during a capture
- Classic terminal view or Modern sidebar/inspector dashboard — switchable from the toolbar

### Tally tab
- Built-in tally light controller for **Waveshare ESP32-S3-ETH** units running the bundled firmware
- Bonjour discovery (`_tally._tcp`) — finds units on the local network automatically
- Manual add by hostname or IP address with automatic sanitization
- Gang mode — fire all units simultaneously with one button
- Individual unit ON/OFF with live reachability status
- **Follow WriteWatch** — tallies fire automatically when WriteWatch detects active writes
  - Manual gang press overrides automation; clears automatically at the next record start
  - Auto / Manual / Recording status shown inline

### Firmware
The ESP32-S3 firmware lives in [`firmware/tally_light/`](firmware/tally_light/tally_light.ino).  
Flash via Arduino IDE with the Waveshare ESP32-S3-ETH board package.  
See the [esp32-smallhd-tally-light](https://github.com/Kunkles/esp32-smallhd-tally-light) repo for full hardware details (W5500 Ethernet, GPIO optocoupler wiring, SmallHD GPI config).

---

## Building from source

Requires **Xcode 15** or later.

```
open "WriteWatch.xcodeproj"
```

Press **⌘R** to build and run. No dependencies — pure SwiftUI + AppKit + AVFoundation.

---

## Architecture

| File | Purpose |
|------|---------|
| `WriteWatchApp.swift` | App entry point; owns `MonitorViewModel` and `TallyStore`; starts recording observer |
| `RootView.swift` | Switches between Classic, Modern, and Tally modes via icon buttons |
| `MonitorViewModel.swift` | Folder list, global stats (`globalActiveCount`, etc.), persistence |
| `WatchedFolder.swift` | Per-folder watcher, tracker, logger, sandbox bookmark |
| `FolderWatcher.swift` | 500 ms polling watcher — works on SMB/NFS |
| `FileTracker.swift` | Core tracking logic — active/completed entries, stale detection, lsof scan |
| `AVProbeService.swift` | AVFoundation media probe — codecs, duration, frame rate, VFR |
| `AppSettings.swift` | Shared preferences (poll interval, passive mode, sounds, etc.) |
| `ContentView.swift` | Classic terminal UI |
| `ModernView.swift` | Modern three-column sidebar/inspector UI |
| `AppTheme.swift` | Terminal colour palette |
| `Models.swift` | `FileEntry`, `FileStatus`, `ValidationState` |
| `Formatters.swift` | Size, rate, duration formatters |
| `BannerView.swift` | ASCII art banner with animated scanline |
| `TerminalComponents.swift` | Terminal panels and table headers |
| `TransfersView.swift` | Active transfers table |
| `CompletedView.swift` | Completed files table |
| `WindowSizeManager.swift` | Per-mode window width persistence and animation |
| **Tally/** | |
| `TallyStore.swift` | Tally state, HTTP control, status polling, WriteWatch automation |
| `TallyUnit.swift` | Unit model — id, name, IP, isOn, isReachable |
| `TallyDiscovery.swift` | Bonjour `_tally._tcp` scanner |
| `TallyRow.swift` | Inline-editable unit row with address sanitization |
| `TallyButtonStyle.swift` | Red/grey tally button style |
| `AddressHelper.swift` | Strips URLs, paths, ports; appends `.local` for bare hostnames |
| `Tally/Views/TallyView.swift` | Tally tab root view |
| `Tally/Views/DiscoveryView.swift` | Bonjour scan sheet |
| `Tally/Views/AddTallyView.swift` | Manual add sheet |

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

### Recent

**v2.1.2-beta** — Fix: crash on macOS 15.7+ when ATS flagged plain HTTP connections to tally units; added `NSAllowsLocalNetworking` so ATS permits local network HTTP without attempting exception reporting.

**v2.1.1-beta** — Fix: tally automation now works regardless of which tab is active. Recording observer runs as a persistent app-level task, not inside TallyView.

**v2.1.0-beta** — Fix: tallies now turn off when WriteWatch stops detecting active writes. Added polling loop and transition guard so gangOff fires reliably on record stop.

**v2.0.0-beta** — Initial v2 release. Tally tab, Follow WriteWatch automation, Bonjour discovery, firmware folder, icon-button toolbar switcher.
