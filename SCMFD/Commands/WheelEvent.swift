import Foundation

/// A single limiter intention. Bindings and modifier handling belong to the server.
nonisolated struct WheelEvent: Equatable, Sendable {
    enum Action: String, Sendable, CaseIterable {
        case speedLimiter
        case accelerationLimiter
    }

    enum Step: Int, Sendable, CaseIterable {
        case increase = 1
        case decrease = -1
    }

    let action: Action
    let step: Step
}
