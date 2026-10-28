/// Commands follow gesture callbacks, independently of whether SwiftUI rendered a pressed frame.
nonisolated struct KeyPressTracker: Sendable {
    private(set) var isDown = false

    mutating func begin() -> Bool {
        guard !isDown else { return false }
        isDown = true
        return true
    }

    /// Used for both a real release and cancellation; the caller decides whether to activate a timed hold.
    mutating func end() -> Bool {
        guard isDown else { return false }
        isDown = false
        return true
    }
}
