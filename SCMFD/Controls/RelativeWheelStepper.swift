/// Converts cumulative vertical drag translation into relative intentions, without delivery or timing.
nonisolated struct RelativeWheelStepper: Sendable {
    enum Intention: Equatable, Sendable {
        case increase
        case decrease
    }

    let distancePerStep: Double
    private(set) var isActive = false
    /// Signed distance left after consuming whole steps; positive means increasing.
    private(set) var remainder: Double = 0
    private var previousTranslation: Double = 0

    /// Rejects zero, negative and non-finite thresholds instead of creating an invalid stepper.
    init?(distancePerStep: Double) {
        guard distancePerStep.isFinite, distancePerStep > 0 else { return nil }
        self.distancePerStep = distancePerStep
    }

    /// Call before the first update of each drag, whose translation starts at zero.
    mutating func begin() {
        reset()
        isActive = true
    }

    /// Negative vertical translation is upward movement and therefore increases.
    ///
    /// Emits at most one intention per update. Excess whole steps are intentionally discarded,
    /// retaining only the signed fractional remainder. Results therefore depend on update
    /// granularity: one large update can emit fewer intentions than several small updates.
    /// This is a distance conversion policy, NOT a network rate limiter.
    mutating func update(translation: Double) -> Intention? {
        guard isActive else { return nil }
        let displacement = previousTranslation - translation
        let accumulated = remainder + displacement
        // Invalid samples or arithmetic overflow cancel the gesture rather than poison its state.
        guard translation.isFinite, displacement.isFinite, accumulated.isFinite else {
            reset()
            return nil
        }
        previousTranslation = translation
        guard abs(accumulated) >= distancePerStep else {
            remainder = accumulated
            return nil
        }
        remainder = accumulated.truncatingRemainder(dividingBy: distancePerStep)
        return accumulated > 0 ? .increase : .decrease
    }

    /// Use on gesture end or cancellation. Updates are ignored until the next begin().
    mutating func reset() {
        isActive = false
        previousTranslation = 0
        remainder = 0
    }
}
