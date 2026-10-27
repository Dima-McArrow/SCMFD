import Observation
import SwiftUI

/// Runs a one-tap timed hold: sends a single `HOLD` event, animates progress for the hold
/// duration, flashes "engaged" at the end and settles back to ready.
/// Tapping again while it runs cancels it and releases the key immediately.
@Observable
final class TimedHoldController {
    private(set) var progress: Double = 0
    private(set) var isRunning = false
    private(set) var isEngaged = false
    /// Increments on every completed hold; used as a haptic trigger.
    private(set) var completions = 0
    /// Why the last hold did not start (busy, game not focused, no link…); clears itself.
    private(set) var rejection: LocalizedStringResource?

    private var task: Task<Void, Never>?
    private var outcomeTask: Task<Void, Never>?
    private var interruptionTask: Task<Void, Never>?

    private let engagedFlash: Duration = .seconds(1.2)

    func toggle(_ action: ShipAction, seconds: Double, link: any CommandLink) {
        if isRunning {
            cancel(action, link: link)
        } else {
            start(action, seconds: seconds, link: link)
        }
    }

    func start(_ action: ShipAction, seconds: Double, link: any CommandLink) {
        task?.cancel()
        outcomeTask?.cancel()
        rejection = nil
        let ticket = link.send(KeyEvent(action: action, phase: .hold(milliseconds: Int((seconds * 1000).rounded()))))
        isRunning = true
        isEngaged = false
        observe(ticket)
        // Subscribe in the same main-actor turn as `send`, before any answer can arrive.
        let interruptions = link.interruptions(of: ticket.id)
        interruptionTask = Task { [weak self] in
            for await reason in interruptions {
                guard let self, self.isRunning else { return }
                self.stop()
                self.flash(InterruptionReason.label(for: reason))
            }
        }

        task = Task { [weak self] in
            // Restart from an empty ring without animating the reset, then fill over the hold.
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { self?.progress = 0 }
            await Task.yield()
            withAnimation(.linear(duration: seconds)) { self?.progress = 1 }

            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            // Ended normally: a later input_cancelled no longer concerns this hold.
            interruptionTask?.cancel()
            interruptionTask = nil
            isRunning = false
            completions += 1
            withAnimation(.easeOut(duration: 0.2)) { self.isEngaged = true }

            try? await Task.sleep(for: engagedFlash)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) {
                self.isEngaged = false
                self.progress = 0
            }
        }
    }

    func cancel(_ action: ShipAction, link: any CommandLink) {
        guard isRunning else { return }
        link.send(KeyEvent(action: action, phase: .up))
        stop()
    }

    /// A hold the server did not start must not keep animating as if the game saw it.
    /// No UP is sent: nothing is held.
    private func observe(_ ticket: CommandTicket) {
        outcomeTask = Task { [weak self] in
            let outcome = await ticket.outcome.value
            guard let self, !Task.isCancelled, let failure = outcome.failureLabel else { return }
            stop()
            flash(failure)
        }
    }

    /// Shows why the hold ended early for a moment, then returns to Ready.
    private func flash(_ label: LocalizedStringResource) {
        withAnimation(.easeOut(duration: 0.2)) { rejection = label }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.rejection == label else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.rejection = nil }
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        interruptionTask?.cancel()
        interruptionTask = nil
        isRunning = false
        withAnimation(.easeOut(duration: 0.3)) {
            progress = 0
            isEngaged = false
        }
    }
}
