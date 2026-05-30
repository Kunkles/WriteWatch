import Foundation

struct DiscoveredUnit: Identifiable {
    let id   = UUID()
    let name: String
    let host: String
}

class TallyDiscovery: NSObject, ObservableObject {
    @Published var discovered: [DiscoveredUnit] = []
    @Published var isScanning = false
    @Published var errorMessage: String? = nil

    private var browser  = NetServiceBrowser()
    private var pending: [NetService] = []

    func startScan() {
        browser.stop()
        browser.delegate = nil
        browser = NetServiceBrowser()
        browser.schedule(in: .main, forMode: .common)
        browser.delegate = self

        discovered.removeAll()
        pending.removeAll()
        errorMessage = nil
        isScanning = true

        browser.searchForServices(ofType: "_tally._tcp", inDomain: "")
    }

    func stopScan() {
        browser.stop()
        isScanning = false
    }
}

extension TallyDiscovery: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool) {
        pending.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didNotSearch errorDict: [String: NSNumber]) {
        let code = errorDict[NetService.errorCode]?.intValue ?? -1
        DispatchQueue.main.async {
            self.isScanning = false
            self.errorMessage = "Scan failed (error \(code)) — check network permissions."
        }
    }
}

extension TallyDiscovery: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        var host = sender.hostName ?? "\(sender.name).local"
        if host.hasSuffix(".") { host = String(host.dropLast()) }
        let unit = DiscoveredUnit(name: sender.name, host: host)

        DispatchQueue.main.async {
            guard !self.discovered.contains(where: { $0.host == unit.host }) else { return }
            self.discovered.append(unit)
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        pending.removeAll { $0 === sender }
    }
}
