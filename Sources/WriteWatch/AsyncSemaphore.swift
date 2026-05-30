import Foundation

/// Limits concurrent async tasks (mirrors Python's threading.Semaphore).
actor AsyncSemaphore {
    private var slots: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { slots = limit }

    func wait() async {
        if slots > 0 { slots -= 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        if let w = waiters.first {
            waiters.removeFirst()
            w.resume()
        } else {
            slots += 1
        }
    }
}
