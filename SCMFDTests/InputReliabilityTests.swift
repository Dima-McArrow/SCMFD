import Foundation
import Testing
@testable import SCMFD

// `#expect` cannot wrap a mutating call (the macro captures the receiver immutably), so each
// `begin()` / `end()` result is stored first.
struct InputReliabilityTests {
    @Test func fastTapEmitsDownAndUpWithoutAVisualUpdate() {
        var press = KeyPressTracker()
        let firstDown = press.begin()
        let repeatedDown = press.begin()
        let firstUp = press.end()
        let repeatedUp = press.end()
        let nextDown = press.begin()
        let nextUp = press.end()
        #expect(firstDown)
        #expect(!repeatedDown)
        #expect(firstUp)
        #expect(!repeatedUp)
        #expect(nextDown)
        #expect(nextUp)
    }

    @Test func duplicateCancellationDoesNotEmitASecondRelease() {
        var press = KeyPressTracker()
        let upBeforeDown = press.end()
        let down = press.begin()
        let up = press.end()
        let repeatedUp = press.end()
        #expect(!upBeforeDown)
        #expect(down)
        #expect(up)
        #expect(!repeatedUp)
        #expect(!press.isDown)
    }
}
