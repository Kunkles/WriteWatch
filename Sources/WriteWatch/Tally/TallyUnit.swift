import Foundation

struct TallyUnit: Identifiable, Codable {
    var id       = UUID()
    var name: String
    var ipAddress: String
    var isOn: Bool        = false
    var isReachable: Bool = true
}
