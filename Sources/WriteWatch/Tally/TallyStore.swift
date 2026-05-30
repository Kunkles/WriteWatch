import Foundation
import SwiftUI

@MainActor
class TallyStore: ObservableObject {
    @Published var units: [TallyUnit] = []
    @Published var gangEnabled: Bool = false

    // WriteWatch recording automation
    @Published var followWriteWatch: Bool = false {
        didSet { UserDefaults.standard.set(followWriteWatch, forKey: "tally.followWriteWatch") }
    }
    // True after a manual gang press while followWriteWatch is on; cleared at next record start
    @Published var manualOverride: Bool = false

    var isAutoMode: Bool { followWriteWatch && !manualOverride }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3
        return URLSession(configuration: config)
    }()

    init() {
        load()
        followWriteWatch = UserDefaults.standard.bool(forKey: "tally.followWriteWatch")
    }

    // MARK: - WriteWatch integration

    func handleRecordChange(isRecording: Bool) {
        guard followWriteWatch else { return }
        if isRecording {
            manualOverride = false   // new record cycle clears manual override
            Task { await gangOn() }
        } else {
            guard !manualOverride else { return }
            Task { await gangOff() }
        }
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(units) {
            UserDefaults.standard.set(data, forKey: "tallyUnits")
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: "tallyUnits"),
           let saved = try? JSONDecoder().decode([TallyUnit].self, from: data) {
            units = saved
        }
    }

    // MARK: - Unit Management

    func addUnit(name: String, ipAddress: String) {
        units.append(TallyUnit(name: name, ipAddress: ipAddress))
        save()
    }

    func removeUnits(at offsets: IndexSet) {
        units.remove(atOffsets: offsets)
        save()
    }

    func updateUnit(_ unit: TallyUnit) {
        guard let index = units.firstIndex(where: { $0.id == unit.id }) else { return }
        units[index] = unit
        save()
    }

    // MARK: - Tally Control

    func setTally(_ unit: TallyUnit, on: Bool, manual: Bool = false) async {
        if manual && followWriteWatch { manualOverride = true }
        let urlString = "http://\(unit.ipAddress)/tally/\(on ? "on" : "off")"
        guard let url = URL(string: urlString) else { return }
        do {
            _ = try await session.data(from: url)
            guard let index = units.firstIndex(where: { $0.id == unit.id }) else { return }
            units[index].isOn = on
            units[index].isReachable = true
        } catch {
            guard let index = units.firstIndex(where: { $0.id == unit.id }) else { return }
            units[index].isReachable = false
        }
        save()
    }

    func gangOn(manual: Bool = false) async {
        if manual && followWriteWatch { manualOverride = true }
        await withTaskGroup(of: Void.self) { group in
            for unit in units {
                group.addTask { await self.setTally(unit, on: true) }
            }
        }
    }

    func gangOff(manual: Bool = false) async {
        if manual && followWriteWatch { manualOverride = true }
        await withTaskGroup(of: Void.self) { group in
            for unit in units {
                group.addTask { await self.setTally(unit, on: false) }
            }
        }
    }

    // MARK: - Status Polling

    func startPolling() async {
        while true {
            await pollAll()
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    func pollAll() async {
        await withTaskGroup(of: Void.self) { group in
            for unit in units {
                group.addTask { await self.pollStatus(unit) }
            }
        }
    }

    private func pollStatus(_ unit: TallyUnit) async {
        guard let url = URL(string: "http://\(unit.ipAddress)/status") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            let body = String(data: data, encoding: .utf8) ?? ""
            guard let index = units.firstIndex(where: { $0.id == unit.id }) else { return }
            units[index].isOn = body.contains("Tally: ON")
            units[index].isReachable = true
        } catch {
            guard let index = units.firstIndex(where: { $0.id == unit.id }) else { return }
            units[index].isReachable = false
        }
    }
}
