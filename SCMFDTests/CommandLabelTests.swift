import Foundation
import Testing
@testable import SCMFD

/// Labels shown on a key when the server cancels or rejects its input (41.10).
struct CommandLabelTests {
    @Test(arguments: CancelReason.allCases)
    func everyKnownCancelReasonHasItsOwnLabel(reason: CancelReason) {
        #expect(InterruptionReason.label(for: reason.rawValue).key != "Cancelled")
    }

    @Test func cancelReasonLabelsAreDistinct() {
        let keys = CancelReason.allCases.map { InterruptionReason.label(for: $0.rawValue).key }
        #expect(Set(keys).count == CancelReason.allCases.count)
    }

    @Test(arguments: [nil, "something_new"] as [String?])
    func unknownOrMissingCancelReasonFallsBackToCancelled(reason: String?) {
        #expect(InterruptionReason.label(for: reason).key == "Cancelled")
    }

    @Test func invalidRejectionSaysNotAllowedOnPC() {
        #expect(CommandOutcome.rejected("invalid").failureLabel?.key == "Not allowed on PC")
    }

    @Test(arguments: ["duplicate", "unknown_action", "unknown_key"])
    func clientBugRejectionsStayGeneric(reason: String) {
        #expect(CommandOutcome.rejected(reason).failureLabel?.key == "Rejected")
    }
}
