import SwiftUI

struct TallyRow: View {
    let unit: TallyUnit
    let gangEnabled: Bool
    let editMode: Bool
    let isSelected: Bool
    let onSelect: (Bool) -> Void
    let onToggle: (Bool) -> Void
    let onUpdate: (TallyUnit) -> Void

    @State private var editedName: String = ""
    @State private var editedIP: String   = ""
    @FocusState private var ipFocused: Bool

    var body: some View {
        HStack(spacing: 12) {

            if editMode {
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { onSelect($0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            }

            Circle()
                .fill(dotColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Name") {
                    TextField("e.g. Camera 1", text: $editedName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveChanges() }
                        .onChange(of: editedName) { saveChanges() }
                }
                .font(.headline)

                LabeledContent("Address") {
                    TextField("e.g. tally-cam1.local", text: $editedIP)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .focused($ipFocused)
                        .onSubmit {
                            editedIP = sanitizeAddress(editedIP)
                            saveChanges()
                        }
                        .onChange(of: ipFocused) { _, focused in
                            if !focused {
                                let cleaned = sanitizeAddress(editedIP)
                                if cleaned != editedIP {
                                    editedIP = cleaned
                                    saveChanges()
                                }
                            }
                        }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            if !editMode {
                if unit.isReachable {
                    HStack(spacing: 8) {
                        Button("ON")  { onToggle(true)  }
                            .buttonStyle(TallyButtonStyle(active: unit.isOn))
                        Button("OFF") { onToggle(false) }
                            .buttonStyle(TallyButtonStyle(active: !unit.isOn))
                    }
                    .disabled(gangEnabled)
                    .opacity(gangEnabled ? 0.3 : 1)
                } else {
                    Text("Unreachable")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            editedName = unit.name
            editedIP   = unit.ipAddress
        }
    }

    private func saveChanges() {
        var updated       = unit
        updated.name      = editedName
        updated.ipAddress = editedIP
        onUpdate(updated)
    }

    private var dotColor: Color {
        if !unit.isReachable { return .orange }
        return unit.isOn ? .red : Color.secondary.opacity(0.3)
    }
}
