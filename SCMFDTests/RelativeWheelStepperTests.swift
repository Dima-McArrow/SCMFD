import Testing
@testable import SCMFD

struct RelativeWheelStepperTests {
    @Test func invalidThresholdsAreRejected() {
        for threshold in [0.0, -1, .infinity, -.infinity, .nan] {
            #expect(RelativeWheelStepper(distancePerStep: threshold) == nil)
        }
        #expect(RelativeWheelStepper(distancePerStep: 0.25) != nil)
        #expect(RelativeWheelStepper(distancePerStep: .leastNonzeroMagnitude) != nil)
    }

    @Test(arguments: [-1.0, 1.0])
    func thresholdBoundariesAndIdenticalUpdates(direction: Double) throws {
        var stepper = try #require(RelativeWheelStepper(distancePerStep: 10))
        let expected: RelativeWheelStepper.Intention = direction < 0 ? .increase : .decrease
        stepper.begin()
        let below = stepper.update(translation: direction * 9.75)
        #expect(below == nil)
        let boundary = stepper.update(translation: direction * 10)
        #expect(boundary == expected)
        let identical = stepper.update(translation: direction * 10)
        #expect(identical == nil)
        let nextBelow = stepper.update(translation: direction * 19.75)
        #expect(nextBelow == nil)
        let nextBoundary = stepper.update(translation: direction * 20)
        #expect(nextBoundary == expected)
        #expect(stepper.remainder == 0)
    }

    @Test func fractionalMovementUsesIncrementalDifferences() throws {
        var stepper = try #require(RelativeWheelStepper(distancePerStep: 2.5))
        stepper.begin()
        let results = [-0.5, -1.25, -2.75, -3.0, -5.0].map {
            stepper.update(translation: $0)
        }
        #expect(results == [nil, nil, .increase, nil, .increase])
        #expect(stepper.remainder == 0)
    }

    @Test(arguments: [-1.0, 1.0])
    func reversalCompensatesSignedRemainder(direction: Double) throws {
        var stepper = try #require(RelativeWheelStepper(distancePerStep: 10))
        stepper.begin()
        let first = stepper.update(translation: direction * 14)
        #expect(first == (direction < 0 ? .increase : .decrease))
        #expect(stepper.remainder == -direction * 4)
        let partialReversal = stepper.update(translation: direction * 12)
        #expect(partialReversal == nil)
        #expect(stepper.remainder == -direction * 2)
        let compensation = stepper.update(translation: direction * 10)
        #expect(compensation == nil)
        #expect(stepper.remainder == 0)
        let belowReverseThreshold = stepper.update(translation: direction * 0.25)
        #expect(belowReverseThreshold == nil)
        let reverse = stepper.update(translation: 0)
        #expect(reverse == (direction < 0 ? .decrease : .increase))
    }

    @Test func beginAlwaysStartsFresh() throws {
        var stepper = try #require(RelativeWheelStepper(distancePerStep: 10))
        stepper.begin()
        _ = stepper.update(translation: -17)
        stepper.begin()
        #expect(stepper.isActive)
        #expect(stepper.remainder == 0)
        let below = stepper.update(translation: -9)
        let boundary = stepper.update(translation: -10)
        #expect(below == nil)
        #expect(boundary == .increase)
    }

    @Test func endOrCancellationResetClearsStateAndIgnoresLateUpdates() throws {
        var stepper = try #require(RelativeWheelStepper(distancePerStep: 10))
        let beforeBegin = stepper.update(translation: -100)
        #expect(beforeBegin == nil)
        stepper.begin()
        _ = stepper.update(translation: -17)
        stepper.reset()
        stepper.reset()
        #expect(!stepper.isActive)
        #expect(stepper.remainder == 0)
        let late = stepper.update(translation: -30)
        #expect(late == nil)
        stepper.begin()
        let below = stepper.update(translation: 9)
        let boundary = stepper.update(translation: 10)
        #expect(below == nil)
        #expect(boundary == .decrease)
    }

    @Test(arguments: [-1.0, 1.0])
    func largeJumpsDiscardWholeStepsButKeepFraction(direction: Double) throws {
        var stepper = try #require(RelativeWheelStepper(distancePerStep: 10))
        let expected: RelativeWheelStepper.Intention = direction < 0 ? .increase : .decrease
        stepper.begin()
        let jump = stepper.update(translation: direction * 1_003)
        #expect(jump == expected)
        #expect(stepper.remainder == -direction * 3)
        let identical = stepper.update(translation: direction * 1_003)
        #expect(identical == nil)
        let below = stepper.update(translation: direction * 1_009)
        #expect(below == nil)
        let boundary = stepper.update(translation: direction * 1_010)
        #expect(boundary == expected)
        #expect(stepper.remainder == 0)
    }

    @Test(arguments: [-1.0, 1.0])
    func overloadIntentionallyDependsOnUpdateGranularity(direction: Double) throws {
        var coarse = try #require(RelativeWheelStepper(distancePerStep: 10))
        var fine = coarse
        coarse.begin()
        fine.begin()
        let coarseResults = [35.0].compactMap { coarse.update(translation: direction * $0) }
        let fineResults = [10.0, 20, 30, 35].compactMap { fine.update(translation: direction * $0) }
        #expect(coarseResults.count == 1)
        #expect(fineResults.count == 3)
        #expect(coarse.remainder == -direction * 5)
        #expect(fine.remainder == coarse.remainder)
    }

    @Test func nonFiniteSamplesCancelGesture() throws {
        for sample in [Double.infinity, -.infinity, .nan] {
            var stepper = try #require(RelativeWheelStepper(distancePerStep: 10))
            stepper.begin()
            let result = stepper.update(translation: sample)
            #expect(result == nil)
            #expect(!stepper.isActive)
            #expect(stepper.remainder == 0)
        }
    }
}
