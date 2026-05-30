import SwiftUI

struct TallyView: View {
    @EnvironmentObject var store: TallyStore
    @EnvironmentObject var vm: MonitorViewModel

    @State private var showingAddTally  = false
    @State private var showingDiscovery = false
    @State private var editMode         = false
    @State private var selectedIDs      = Set<UUID>()

    // Drives re-evaluation of globalActiveCount — MonitorViewModel only publishes
    // when the folders array changes, not when tracker entries inside folders change.
    private let recordingTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isRecording: Bool { vm.globalActiveCount > 0 }

    var body: some View {
        NavigationStack {
            List {

                // --- WriteWatch Automation ---
                Section {
                    Toggle("Follow WriteWatch", isOn: $store.followWriteWatch)
                        .tint(.red)

                    if store.followWriteWatch {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.isAutoMode ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(store.isAutoMode ? "Auto" : "Manual override")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isRecording {
                                Label("Recording", systemImage: "record.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("WriteWatch")
                } footer: {
                    if store.followWriteWatch {
                        Text("Tallies fire automatically when WriteWatch detects active writes. Manual gang presses override until the next recording cycle.")
                    }
                }

                // --- Gang Control ---
                Section {
                    Toggle("Gang Mode", isOn: $store.gangEnabled)
                        .tint(.red)

                    if store.gangEnabled {
                        HStack(spacing: 12) {
                            Button("RECORD ON") {
                                Task { await store.gangOn(manual: true) }
                            }
                            .buttonStyle(TallyButtonStyle(active: true))
                            .frame(maxWidth: .infinity)

                            Button("RECORD OFF") {
                                Task { await store.gangOff(manual: true) }
                            }
                            .buttonStyle(TallyButtonStyle(active: false))
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Gang Control")
                } footer: {
                    if store.gangEnabled {
                        Text("Individual controls are disabled while gang mode is on.")
                    }
                }

                // --- Individual Units ---
                Section {
                    ForEach(store.units) { unit in
                        TallyRow(
                            unit: unit,
                            gangEnabled: store.gangEnabled,
                            editMode: editMode,
                            isSelected: selectedIDs.contains(unit.id),
                            onSelect: { selected in
                                if selected { selectedIDs.insert(unit.id) }
                                else        { selectedIDs.remove(unit.id) }
                            },
                            onToggle: { on in
                                Task { await store.setTally(unit, on: on, manual: true) }
                            },
                            onUpdate: { updated in
                                store.updateUnit(updated)
                            }
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                if let idx = store.units.firstIndex(where: { $0.id == unit.id }) {
                                    store.removeUnits(at: IndexSet([idx]))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Units  (\(store.units.count))")
                }
            }
            .navigationTitle("Tally")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if editMode && !selectedIDs.isEmpty {
                        Button(role: .destructive) {
                            deleteSelected()
                        } label: {
                            Label("Delete Selected", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if !editMode {
                        HStack {
                            Button {
                                showingDiscovery = true
                            } label: {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            .help("Discover tally units on the network")

                            Button {
                                showingAddTally = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .help("Add unit manually")
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(editMode ? "Done" : "Edit") {
                        editMode.toggle()
                        if !editMode { selectedIDs.removeAll() }
                    }
                }
            }
            .task {
                await store.startPolling()
            }
            .onChange(of: vm.globalActiveCount) { _, count in
                store.handleRecordChange(isRecording: count > 0)
            }
            .onReceive(recordingTimer) { _ in
                vm.objectWillChange.send()
                store.handleRecordChange(isRecording: vm.globalActiveCount > 0)
            }
            .sheet(isPresented: $showingAddTally) {
                AddTallyView { name, ip in
                    store.addUnit(name: name, ipAddress: ip)
                }
            }
            .sheet(isPresented: $showingDiscovery) {
                DiscoveryView(
                    existingHosts: Set(store.units.map { $0.ipAddress })
                ) { name, host in
                    store.addUnit(name: name, ipAddress: host)
                }
            }
        }
    }

    private func deleteSelected() {
        let offsets = store.units.enumerated()
            .filter { selectedIDs.contains($0.element.id) }
            .map    { $0.offset }
        store.removeUnits(at: IndexSet(offsets))
        selectedIDs.removeAll()
        editMode = false
    }
}
