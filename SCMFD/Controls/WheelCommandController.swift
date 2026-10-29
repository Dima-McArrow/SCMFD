import Foundation
import Observation

/// One pending wheel request across both limiter drums, with no queued intentions.
@Observable
final class WheelCommandController {
    private(set) var isPending = false
    private(set) var failures: [WheelEvent.Action: CommandOutcome] = [:]

    func failure(for action: WheelEvent.Action) -> LocalizedStringResource? {
        failures[action]?.failureLabel
    }

    /// Returns nil for a dropped intention. The task observes settlement even if the page disappears.
    @discardableResult
    func submit(_ intention: RelativeWheelStepper.Intention, for action: WheelEvent.Action,
                link: any CommandLink) -> Task<Void, Never>? {
        guard !isPending else { return nil }
        isPending = true
        failures[action] = nil
        let step: WheelEvent.Step = intention == .increase ? .increase : .decrease
        let ticket = link.send(wheel: WheelEvent(action: action, step: step))
        return Task {
            let outcome = await ticket.outcome.value
            if outcome.failureLabel != nil {
                failures[action] = outcome
            }
            isPending = false
        }
    }
}
