import Foundation
import Testing
@testable import SCMFD

/// The Debug tab shows what the server sent: the raw Game.log name first, since FIX-08 is built from it.
struct DebugStateRowsTests {
    private func qtRow(internal internalName: String?, display: String?,
                       mode: QuantumTargetStatus.Mode = .destination) -> String? {
        let target = QuantumTargetStatus(mode: mode, internalName: internalName, displayName: display,
                                         confidence: .confirmed, observedAt: nil)
        let state = ServerState(sessionId: UUID(), seq: 1, partial: true, game: .absent, log: .absent,
                                ship: .absent, shipContext: .absent, qtTarget: .value(target),
                                hangarRequest: .absent)
        return SecureConnectionDebugSection.stateRows(state).first { $0.0 == "QT target" }?.1
    }

    @Test func rawNameWinsOverTheServerDisplayName() {
        #expect(qtRow(internal: "OOC_Stanton_1_Hurston", display: "Hurston") == "OOC_Stanton_1_Hurston")
    }

    @Test func displayNameIsShownWithoutARawName() {
        #expect(qtRow(internal: nil, display: "Hurston") == "Hurston")
    }

    @Test func modeIsShownWithoutAnyName() {
        #expect(qtRow(internal: nil, display: nil, mode: .freeMode) == "freeMode")
    }
}
