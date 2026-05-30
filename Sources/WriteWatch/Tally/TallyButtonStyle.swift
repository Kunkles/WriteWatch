import SwiftUI

struct TallyButtonStyle: ButtonStyle {
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(active ? Color.red : Color.secondary.opacity(0.2))
            .foregroundColor(active ? .white : .secondary)
            .cornerRadius(7)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
