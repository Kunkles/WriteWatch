import SwiftUI

struct DiscoveryView: View {
    @StateObject private var discovery = TallyDiscovery()
    @Environment(\.dismiss) private var dismiss

    let existingHosts: Set<String>
    let onAdd: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if discovery.discovered.isEmpty {
                    emptyState
                } else {
                    unitList
                }
            }
            .navigationTitle("Discover Units")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if discovery.isScanning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Button("Stop") { discovery.stopScan() }
                        }
                    } else {
                        Button("Scan Again") { discovery.startScan() }
                    }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 300)
        .onAppear   { discovery.startScan() }
        .onDisappear { discovery.stopScan() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            if discovery.isScanning {
                ProgressView()
                Text("Scanning for tally units…")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "network.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text("No tally units found")
                    .font(.headline)
                if let err = discovery.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Make sure units are powered on and on the same network.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unitList: some View {
        List(discovery.discovered) { unit in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(unit.name)
                        .font(.headline)
                    Text(unit.host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if existingHosts.contains(unit.host) {
                    Text("Already added")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Add") {
                        onAdd(unit.name, unit.host)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
