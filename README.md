# WriteWatch — Native macOS SwiftUI App

Real-time video transfer monitor with a terminal/TUI aesthetic.  
Swift port of `writewatch.py` using native AVFoundation for file validation.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later

## Creating the Xcode Project (takes ~2 minutes)

1. Open Xcode → **File → New → Project**
2. Choose **macOS → App**, click Next
3. Fill in:
   - Product Name: `WriteWatch`
   - Bundle Identifier: `com.yourname.WriteWatch`  
   - Interface: **SwiftUI**
   - Language: **Swift**
   - ✅ Include Tests: unchecked
4. Choose a location, **Create**

### Add the source files

5. In the Xcode Project Navigator, delete the auto-generated `ContentView.swift`  
   (Move to Trash when prompted)
6. Drag **all `.swift` files** from this folder into the `WriteWatch` group in Xcode  
   — check "Copy items if needed" and make sure "Add to target: WriteWatch" is selected

### Configure the target

7. Click the project in the Navigator → select the **WriteWatch** target
8. **General tab:**
   - Deployment Target: `13.0`
9. **Build Settings tab:**
   - Search "Swift Language Version" → set to `Swift 5`
10. **Signing & Capabilities tab:**
    - Sign in with your Apple ID if not already
    - Click **+ Capability** → add **App Sandbox**
    - Under "File Access" enable: **User Selected File: Read Only**

### Set the entitlements (optional hardening)

11. Replace the auto-generated `.entitlements` file content with the contents  
    of `WriteWatch.entitlements` from this folder.

### Update Info.plist

12. Replace the project's `Info.plist` with the one from this folder,  
    or merge the keys manually.

### Build & Run

13. Press **⌘R** — the app should launch showing the WriteWatch terminal UI.

---

## Usage

- Click **Choose Folder** in the toolbar (or drag a folder onto the window)
- The app scans existing video files and begins monitoring for new/growing ones
- Active transfers appear in the top table with live rate, peak, and elapsed time
- When a transfer goes idle for ~4 seconds it moves to the Completed table and  
  AVFoundation probes the container for validity
- Toggle the speaker icon to enable macOS system sounds on events

## Architecture notes

| File | Purpose |
|------|---------|
| `WriteWatchApp.swift` | `@main` entry point |
| `AppTheme.swift` | Terminal colour palette & fonts |
| `Models.swift` | `FileEntry`, `ValidationState`, `FileStatus` |
| `Formatters.swift` | `fmtSize`, `fmtRate`, `fmtDur`, `nowFull` |
| `AsyncSemaphore.swift` | Actor-based semaphore (limits concurrent probes to 3) |
| `FileTracker.swift` | `@MainActor ObservableObject` — core tracking logic |
| `FolderWatcher.swift` | 500 ms polling watcher (works on SMB/NFS too) |
| `AVProbeService.swift` | Native AVFoundation media probe (replaces ffprobe) |
| `BannerView.swift` | ASCII art banner — rainbow idle / red scanline active |
| `TerminalComponents.swift` | Reusable terminal panel, table header, spinner |
| `TransfersView.swift` | Active transfers table |
| `CompletedView.swift` | Completed files table |
| `ContentView.swift` | Root view — toolbar, drop target, layout |

## lsof and App Sandbox

The "still open" file check uses `/usr/sbin/lsof` via `Process()`.  
The App Sandbox blocks subprocess spawning, so this check is silently  
skipped when sandboxed. AVFoundation's `isReadable` check catches most  
truncated/incomplete files on its own.

To enable lsof, disable the sandbox in Build Settings  
(`ENABLE_APP_SANDBOX = NO`) — valid for internal/developer use.
