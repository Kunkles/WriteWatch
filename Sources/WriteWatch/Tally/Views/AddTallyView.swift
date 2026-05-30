import SwiftUI

struct AddTallyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name      = ""
    @State private var ipAddress = ""

    let onAdd: (String, String) -> Void

    var sanitized: String { sanitizeAddress(ipAddress) }
    var showPreview: Bool  { !ipAddress.isEmpty && sanitized != ipAddress }
    var isValid: Bool      { !name.isEmpty && !ipAddress.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name  (e.g. Camera 1)", text: $name)
                    TextField("IP address or hostname", text: $ipAddress)
                        .autocorrectionDisabled()
                } footer: {
                    if showPreview {
                        Label("Will be saved as: \(sanitized)", systemImage: "wand.and.stars")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    } else {
                        Text("Enter an IP address or hostname. Paste a full URL and it will be cleaned up automatically.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Tally")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name, sanitized)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
