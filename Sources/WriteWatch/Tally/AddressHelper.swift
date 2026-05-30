import Foundation

/// Cleans up a user-entered address into a bare hostname or IP.
/// Strips http(s)://, paths, port numbers; appends .local for bare hostnames.
func sanitizeAddress(_ input: String) -> String {
    var s = input.trimmingCharacters(in: .whitespaces).lowercased()

    for scheme in ["https://", "http://"] {
        if s.hasPrefix(scheme) { s = String(s.dropFirst(scheme.count)) }
    }

    if let slash = s.firstIndex(of: "/") {
        s = String(s[s.startIndex ..< slash])
    }

    if !s.hasPrefix("["), let colon = s.lastIndex(of: ":") {
        let afterColon = s[s.index(after: colon)...]
        if afterColon.allSatisfy({ $0.isNumber }) {
            s = String(s[s.startIndex ..< colon])
        }
    }

    s = s.trimmingCharacters(in: .whitespaces)

    let isIP = s.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#,
                       options: .regularExpression) != nil
    if !isIP && !s.isEmpty && !s.contains(".") {
        s += ".local"
    }

    return s
}
