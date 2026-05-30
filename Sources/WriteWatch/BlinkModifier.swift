import SwiftUI

/// Pulses opacity between full and dim while `active` is true.
/// Used to draw attention to critical disk-space warnings.
struct BlinkModifier: ViewModifier {
    let active: Bool
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(active ? (dim ? 0.25 : 1.0) : 1.0)
            .animation(
                active
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : .default,
                value: dim
            )
            .onAppear { if active { dim = true } }
            .onChange(of: active) { _, isActive in
                dim = isActive
            }
    }
}

extension View {
    /// Blink this view (opacity pulse) while `active` is true.
    func blink(_ active: Bool) -> some View {
        modifier(BlinkModifier(active: active))
    }
}
