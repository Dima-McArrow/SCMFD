import Foundation
import Testing
@testable import SCMFD

struct InputReliabilityTests {
    @Test func fastTapEmitsDownAndUpWithoutAVisualUpdate() {
        var press = KeyPressTracker()
        #expect(press.begin())
        #expect(!press.begin())
        #expect(press.end())
        #expect(!press.end())
        #expect(press.begin())
        #expect(press.end())
    }

    @Test func duplicateCancellationDoesNotEmitASecondRelease() {
        var press = KeyPressTracker()
        #expect(!press.end())
        #expect(press.begin())
        #expect(press.end())
        #expect(!press.end())
        #expect(!press.isDown)
    }
}
