import SwiftUI

final class ClassicColumnState: ObservableObject {

    @Published var folder:   CGFloat = 110
    @Published var filename: CGFloat = 200
    @Published var size:     CGFloat = 80
    @Published var rate:     CGFloat = 95
    @Published var peak:     CGFloat = 95
    @Published var elapsed:  CGFloat = 72
    @Published var status:   CGFloat = 90
    @Published var validCol: CGFloat = 260

    let minW:  CGFloat = 50
    let maxW:  CGFloat = 400

    func clamp(_ v: CGFloat) -> CGFloat { min(max(v, minW), maxW) }

    // Natural table width at default column sizes.
    // charW per handle (┊) between each column + 4 indent + 32 outer padding.
    var defaultTableWidth: CGFloat {
        filename + charW
        + size    + charW
        + rate    + charW
        + peak    + charW
        + elapsed + charW
        + status
        + 4
        + 32
        + 16
    }
}
