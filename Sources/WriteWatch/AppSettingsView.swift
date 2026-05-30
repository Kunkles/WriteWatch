import SwiftUI

struct AppSettingsView: View {
    @ObservedObject private var s = AppSettings.shared

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            SoundSettingsTab()
                .tabItem { Label("Sound",   systemImage: "speaker.wave.2") }
            ValidationSettingsTab()
                .tabItem { Label("Validation", systemImage: "checkmark.seal") }
            LoggingSettingsTab()
                .tabItem { Label("Logging", systemImage: "doc.text") }
            DisplaySettingsTab()
                .tabItem { Label("Display", systemImage: "display") }
        }
        .frame(width: 460)
        .fixedSize()
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject private var s = AppSettings.shared

    var body: some View {
        Form {
            Section("Safety") {
                Toggle("Passive mode (recommended for capture drives)", isOn: $s.passiveMode)
                Text("When on, WriteWatch only reads file sizes and never runs lsof or any subprocess, avoiding filesystem contention that could disrupt a camera recording to the watched drive. Mid-recording detection still works.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Start watching automatically on launch", isOn: $s.autoStartOnLaunch)
                Text("When on, all remembered folders begin watching as soon as the app opens. When off, they're loaded but paused until you press Start.")
                    .font(.caption).foregroundStyle(.secondary)

                Toggle("Scan for existing files on launch", isOn: $s.scanExistingOnLaunch)
                Text("When on, remembered folders are re-scanned at launch so files already on disk appear in the completed list (each is re-validated). Turn off for faster startup on drives with many large files.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Write Detection") {
                LabeledContent("Write-complete threshold") {
                    HStack {
                        Slider(value: $s.staleSeconds, in: 1...30, step: 0.5)
                        Text(String(format: "%.1f s", s.staleSeconds))
                            .monospacedDigit()
                            .frame(width: 48)
                    }
                }
                Text("How long a file must have no size change before it's considered done writing.")
                    .font(.caption).foregroundStyle(.secondary)

                LabeledContent("Poll interval") {
                    HStack {
                        Slider(value: $s.pollInterval, in: 0.1...5.0, step: 0.1)
                        Text(String(format: "%.1f s", s.pollInterval))
                            .monospacedDigit()
                            .frame(width: 48)
                    }
                }
                Text("How often the folder is polled for size changes. Lower = more responsive, higher CPU.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("New Folder Defaults") {
                Toggle("Watch sub-folders recursively", isOn: $s.recursive)
                Toggle("Force polling watcher (for SMB / NFS mounts)", isOn: $s.forcePolling)
                Text("These apply when a folder is first added. Per-folder overrides are in the folder settings sheet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}

// MARK: - Sound

private struct SoundSettingsTab: View {
    @ObservedObject private var s = AppSettings.shared

    // (label, eventKey, displayName, isCustom)
    // isCustom=true means it's a bundled AIFF, looked up by displayName in Resources/
    private let events: [(String, String, String, Bool)] = [
        ("Started recording",  "started",  "rec_start", true),
        ("Transfer complete",  "complete", "Ping",      false),
        ("File valid",         "valid",    "Hero",      false),
        ("File corrupt",       "corrupt",  "Basso",     false),
        ("File still open",    "open",     "Funk",      false),
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Enable sounds", isOn: $s.soundEnabled)
                Text("Plays a macOS system sound when key events occur.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Events") {
                ForEach(events, id: \.0) { (label, _, sound, isCustom) in
                    HStack {
                        Image(systemName: isCustom ? "waveform" : "speaker.wave.1")
                            .foregroundStyle(s.soundEnabled ? .primary : .secondary)
                        Text(label)
                            .foregroundStyle(s.soundEnabled ? .primary : .secondary)
                        Spacer()
                        Text(isCustom ? "custom" : sound)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button("▶") {
                            if isCustom,
                               let url = Bundle.main.url(forResource: sound, withExtension: "aiff") {
                                NSSound(contentsOf: url, byReference: true)?.play()
                            } else {
                                NSSound(named: NSSound.Name(sound))?.play()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(s.soundEnabled ? Color.accentColor : Color.secondary)
                        .disabled(!s.soundEnabled)
                        .help("Preview")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}

// MARK: - Validation

private struct ValidationSettingsTab: View {
    @ObservedObject private var s = AppSettings.shared

    var body: some View {
        Form {
            Section("Engine") {
                Toggle("Enable file validation", isOn: $s.validationEnabled)
                Text("Uses AVFoundation to check container integrity and report codecs after each transfer completes.")
                    .font(.caption).foregroundStyle(.secondary)

                LabeledContent("Engine") {
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        Text("AVFoundation (built-in)")
                    }
                }
            }

            Section("Concurrency") {
                LabeledContent("Max concurrent probes") {
                    Stepper("\(s.maxConcurrentProbes)",
                            value: $s.maxConcurrentProbes, in: 1...8)
                }
                Text("Higher values validate faster on multi-core systems but use more CPU during scans.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Mid-Write Detection") {
                Toggle("Show mid-join badge on late-added files", isOn: $s.showMidJoinBadge)
                Text("When a folder is added while a file is already being written, marks the completed entry with ⟳ to indicate the observed size may not be the total.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}

// MARK: - Logging

private struct LoggingSettingsTab: View {
    @ObservedObject private var s = AppSettings.shared

    var body: some View {
        Form {
            Section("Log Files") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default label")
                        .font(.callout)
                    // labelsHidden() stops the Form from hoisting the
                    // placeholder out as a leading field label, so "StageOne"
                    // renders as grey placeholder text INSIDE the box.
                    TextField(AppSettings.computerName, text: $s.defaultLabel)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                    Text("Appended to log filenames so you can tell shoots apart. Can be overridden per folder.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section("Thresholds") {
                LabeledContent("Progress log threshold") {
                    HStack {
                        Slider(value: $s.progressThreshMB, in: 10...500, step: 10)
                        Text(String(format: "%.0f MB", s.progressThreshMB))
                            .monospacedDigit()
                            .frame(width: 55)
                    }
                }
                Text("Log a progress entry every time a file grows by this amount.")
                    .font(.caption).foregroundStyle(.secondary)

                LabeledContent("Snapshot interval") {
                    HStack {
                        Slider(value: $s.snapshotInterval, in: 10...300, step: 10)
                        Text(String(format: "%.0f s", s.snapshotInterval))
                            .monospacedDigit()
                            .frame(width: 45)
                    }
                }
                Text("How often a summary snapshot is written to the log while transfers are active.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}

// MARK: - Display

private struct DisplaySettingsTab: View {
    @ObservedObject private var s = AppSettings.shared
    var body: some View {
        Form {
            Section("On Launch") {
                Picker("Default view", selection: $s.defaultMode) {
                    Text("Modern").tag("modern")
                    Text("Classic").tag("classic")
                }
                .pickerStyle(.radioGroup)
            }

            Section("Classic View") {
                HStack {
                    Text("Column widths")
                    Spacer()
                    Button("Reset to defaults") {
                        // Post a notification — RootView resets ClassicColumnState
                        NotificationCenter.default.post(
                            name: .resetClassicColumns, object: nil)
                    }
                    .buttonStyle(.bordered)
                }
                Text("Drag the ┊ handles in the Classic view header row to resize columns. Use Reset to restore defaults.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Toggle("Show mid-join badge (⟳) in completed table", isOn: $s.showMidJoinBadge)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let resetClassicColumns = Notification.Name("ww.resetClassicColumns")
}
