# WriteWatch Changelog

All notable changes are documented here.
Format: [version] — date — summary

---

## [1.8.3-beta] — 2026-05-28

### Fixed
- **Restored folders now actively watch immediately** — the previous build made
  the watcher wait for scanExisting to finish before starting, which meant new
  recordings written shortly after launch weren't detected. The watcher now
  starts immediately and the scan runs in parallel, with an internal
  `isScanning` flag preventing pre-existing files from being mis-classified as
  active during the race window.

---

## [1.8.2-beta] — 2026-05-28

### Added
- **"Rescan All Folders"** menu command (File → Rescan All Folders, ⌘⇧R), and
  also surfaced in the toolbar overflow menus on both views. Re-scans every
  watched folder for existing files on disk and repopulates the completed list.

### Fixed
- `restoreFolders()` now guards against running more than once per session
  (SwiftUI can fire `.onAppear` multiple times during launch, which would
  bail out partway through scan setup).

---

## [1.8.1-beta] — 2026-05-28

### Fixed
- "Scan for existing files on launch" now actually works — the scan was racing
  the file watcher: when the watcher started polling in parallel, it would
  discover pre-existing files first and incorrectly mark them as Active rather
  than Completed. The watcher now starts only after the scan finishes.

---

## [1.8.0-beta] — 2026-05-28

### Added
- **Scan for existing files on launch** (on by default) — remembered folders
  are re-scanned at startup so files already on disk show up in the completed
  list. Can be turned off in Preferences → General → Startup for faster launch
  on drives with many large files.

---

## [1.7.1-beta] — 2026-05-28

### Fixed
- Folders restored on launch could occasionally load without actually
  watching (had to be removed and re-added). Restore is now deferred one
  run-loop tick, the stale timer runs in .common run-loop mode, and start()
  guards on the watcher object rather than the isWatching flag — so a restored
  folder reliably begins watching.

---

## [1.7.0-beta] — 2026-05-28

### Added
- **Auto-start on launch** (on by default) — remembered folders now begin
  watching automatically when the app opens. Can be turned off in
  Preferences → General → Startup, in which case folders load paused until
  you press Start.

---

## [1.6.1-beta] — 2026-05-28

### Changed
- New app icon — brighter, cleaner background (blue-grey slate) with more
  saturated artwork. Replaces the darker, muddier original.

---

## [1.6.0-beta] — 2026-05-28

### Added
- The default log label now auto-fills with the computer's name on first launch,
  so logs are meaningfully named even if never changed. The field's placeholder
  also shows the computer name as the fallback.

### Fixed
- Log-label field in Preferences now renders as a proper bordered text field with
  the placeholder shown inside it (was being mis-rendered as a leading label).

---

## [1.5.1-beta] — 2026-05-27

### Fixed
- The Modern view's toolbar button now opens the real app Preferences (⌘,)
  instead of an orphaned per-folder settings sheet whose controls didn't take
  effect. Removed that dead settings sheet entirely.

### Changed
- Added a Preferences (gear) button to both the Modern and Classic toolbars.

---

## [1.5.0-beta] — 2026-05-27

### Added
- **Persistent folders** — watched folders are remembered and automatically
  re-added on launch. Folders that no longer exist (e.g. unmounted drives)
  are silently skipped.
- **File menu commands**:
  - "Clear All Folders…" — removes every watched folder (with confirmation)
  - "Clear Completed History…" — clears the completed-files display on all
    folders while keeping watched folders and active transfers (with confirmation)
- **Quit confirmation** — if any transfers are actively writing when you try
  to quit, a confirmation dialog appears explaining that the camera files on
  disk are unaffected; only the monitoring will stop.

---

## [1.4.0-beta] — 2026-05-27

### Added
- **Started-recording sound** — a custom two-tone beep (600 Hz lead + 1000 Hz trail,
  with a brief gap) plays the first time a new file is detected being written.
  Bundled as `rec_start.aiff` in app Resources. Shows up in Preferences → Sound
  with a preview button alongside the other event sounds.

---

## [1.3.0-beta] — 2026-05-27

### Added
- **Embedded frame rate** is now shown for each completed file in both views,
  next to the codec/validation info (e.g. "prores422hq  pcm  29.97 fps").
  Snaps to standard broadcast rates (23.976 / 24 / 25 / 29.97 / 30 / 50 /
  59.94 / 60 / 120); non-standard rates show two decimals.

### Fixed
- Frame rate is now read from the exact rational frame duration (CMTime)
  rather than the rounded nominalFrameRate float, so true 30 fps footage no
  longer mis-reports as 29.97 (and vice-versa).

---

## [1.2.0-beta] — 2026-05-26

### Added
- **Passive mode** (on by default) — WriteWatch now only reads file sizes and
  never spawns lsof or any subprocess, eliminating filesystem contention that
  could interfere with a camera actively recording to the watched drive.
- **VFR detection** — files with a variable frame rate are flagged with a "VFR"
  badge in both views (compares nominal vs. peak frame rate during the probe).
- Disk-space warning now blinks for any low-space red state (< 200 GB), with a
  brighter urgent red under 100 GB.

### Changed
- Sound is now ON by default.
- Default poll interval raised to 1.0s (gentler on capture drives).
- Duration-match comparison now subtracts the stale-detection tail before
  comparing to media length, so the green "match" threshold is an accurate 1.5s.

### Fixed
- **Recursive setting now works** — turning off "Watch sub-folders recursively"
  correctly limits both the live watcher and the initial scan to the top-level
  folder only (previously always recursed).
- Poll interval setting is now actually honored by the folder watcher
  (was hardcoded to 500ms).

---

## [1.1.0-beta] — 2026-05-26

### Added
- **Disk space monitoring** — each watched folder now reports free space, total
  capacity, and percentage used on its volume. Shown in the Modern inspector
  (Storage section with a usage bar), the Modern bottom status bar, and the
  Classic banner folder lines. Color-coded: green < 85%, yellow 85–95%, red > 95%.
- **Duration accuracy coloring** — the DURATION column now compares the recording's
  wall-clock elapsed time against the file's actual media playback length:
  bright green when they match (within ~1.5s), yellow when slightly off (within 5s),
  red when significantly off, and purple for imported (not-recorded-live) files.
- **Media duration for all files** — the DURATION column shows the real playback
  length of every completed file (from the AVFoundation probe), including
  pre-existing files found when a folder is added.

### Changed
- Classic banner watch section reformatted: "WATCHING:" header on its own line,
  one line per folder below with right-justified status/space info that adapts
  to window width instead of overflowing.
- Retro pixel-art logo replaced with a resolution-correct low-res version,
  height-locked to the ASCII logo so it stays docked regardless of window size
  or number of watched folders.
- Default Classic column widths retuned to better fit real content.
- All completed files now shown in Classic view (previously capped at 5).

### Fixed
- Mid-recording detection: files already being written when a folder is added
  are now correctly tracked (previously stuck as "done").
- Sounds now respond to the preferences toggle live, without restarting.
- Performance: idle-state CPU greatly reduced (logo animation throttled when
  idle, lsof scan optimized to avoid full-system file-descriptor walks,
  redundant re-renders removed).
- Full-screen mode no longer shows stray off-screen toolbar buttons when
  switching between Classic and Modern views.
- Various banner text wrapping/truncation issues.

---

## [1.0.0-beta] — 2026-05-26

First full release. Complete rewrite from Python (`writewatch.py`) to a
native macOS SwiftUI application.

### Classic View (terminal aesthetic)
- Full-width ASCII banner with animated rainbow idle state and red/white
  scanline sweep during active transfers — driven by `TimelineView` at
  60 fps for smooth animation
- Retro pixel-art logo displayed alongside the banner
- Double-line box borders (`╔══╗`) around Active Transfers and Completed
  Files panels
- Drag-resizable columns via `┊` handles in the header row; widths persist
  across sessions via `@AppStorage`
- Aggregates transfers across all watched folders into unified panels;
  FOLDER column appears automatically when multiple folders are active
- All completed files shown (no cap), newest first

### Modern View (native macOS dashboard)
- Three-column `NavigationSplitView`: sidebar / file table / inspector
- Sidebar sections: Watched Folders, Overview (All Writing / All Completed),
  Smart Folders (All Files / Writing / Completed / Valid / Corrupt) with
  live counts
- Sortable `Table` with Name, Size, Rate, Peak, Elapsed, Status, Validation
- Per-folder activity log with autoscroll and Files / Activity Log tab switcher
- Folder inspector: Location, Observer type, App version, This Session stats,
  All Folders global stats
- File inspector: Info, Status, Validation sections
- Master Play / Stop All button in sidebar toolbar
- Per-folder settings sheet (stale threshold, poll interval, label, etc.)

### Shared infrastructure
- Both views share a single `MonitorViewModel` — folders added in Classic
  appear in Modern and vice versa
- Window width remembered per view mode; animated resize on switch; Classic
  defaults to natural table width on first launch
- `FolderWatcher` polling (500 ms) works on SMB / NFS mounts where FSEvents
  is unreliable
- `AVProbeService` validates completed files using AVFoundation (no ffprobe
  dependency); reports codecs and duration
- Mid-write detection: `lsof -F pfan` scans every 2 seconds for video files
  held open for writing that weren't caught by the poller; late-added files
  are tracked from the moment of discovery and marked with ⟳ badge
- Final size reconciliation: after a mid-join file completes, the true file
  size is read from disk and session totals are corrected
- 12-second discovery grace period prevents newly-discovered files from being
  prematurely marked stale
- Sound events: transfer complete, valid, corrupt, still open (system sounds,
  toggled globally or per folder)
- `AsyncSemaphore` limits concurrent AVFoundation probes to 3 (configurable)

### App settings (⌘,)
- **General**: write-complete threshold, poll interval, recursive, force polling
- **Sound**: global toggle, per-event preview buttons
- **Validation**: enable/disable, max concurrent probes, mid-join badge toggle
- **Logging**: default label, progress threshold, snapshot interval
- **Display**: default launch view, reset Classic column widths

### App icon
- Custom retro pixel-art icon (folder + film strip + eye) with squircle
  transparency mask matching Apple's icon shape; all 10 macOS icon sizes
  generated (16 × 16 through 512 × 512 @ 2×)

---

## Earlier development (pre-release)

### Python prototype (`writewatch.py`)
- CLI tool using `watchdog` for folder monitoring, `rich` for terminal UI,
  `ffprobe` for validation
- Polled for file size changes, marked files stale after configurable timeout
- Logged to timestamped `.log` files

### AVProbeService.swift (handoff file)
- Native AVFoundation replacement for ffprobe
- Async probing with `AVAsset.load(.duration)` and `loadTracks(withMediaType:)`
- Returns codec strings and duration detail for the validation column
