# QT: last observed local selection, BE handoff

Date: 2026-10-29.

Status: BE implementation completed. FE application/test sources and the existing shared spec are unchanged
in this step, at the owner's request. This document records the semantic update and required Mac checks.

## Owner decision

An explicit `Player Selected Quantum Target - Local` record is sufficient evidence of the local player's
selected QT destination. Assume this selection is made in a ship, without requiring proof of a recognized
ship channel, a spawn or a match with `ship.entityId`. Do not invent a ship name, identity or Deck transition.

The previous ship-binding gate dropped all 24 selection records in the 28/29 October game sessions before
the Corsair fix. The source records existed; they were blocked by missing context or entity binding.

## BE behavior

- The same single reader and existing parser recognize the explicit local-selection marker.
- The latest parsed local selection replaces `state.qtTarget` even when `ship` is null or its ID differs.
- Model/entity fields in the source can still enrich the existing ship-binding mechanism when its old rules
  succeed. They are not prerequisites for publishing QT and do not create a ship context by themselves.
- `mode=destination`, `internalName` is the exact bounded source identifier, `displayName=null`,
  `confidence=confirmed`, and `observedAt` is the source timestamp. Confirmed means that a selection was
  explicitly observed; it does not prove a currently locked target, jump completion or current ship identity.
- No wire fields, enums or protocol version changed. Existing state coalescing and full snapshots are reused.
- No new reader, polling, timer, history, input action or BE name-resolution calculation is introduced.
- Ship-channel joins/leaves, ClearDriver and vehicle destruction preserve the last local selection.
- A verified PU exit, SystemQuit/process exit or log-generation reset clears QT to unknown. A later exit also
  clears a selection received after menu reentry without a new ship channel, even if shipContext still says
  gameEnded; this does not manufacture another ship revision.
- Generic navigation, remote selection markers and malformed/overlong target names do not set a destination.

Missing selection records cannot be reconstructed. In particular, the Cutter log before the first menu exit
had no recognized local-selection record. This change cannot recover an event the log did not record.
There is no validated clear-target/free-mode source, so the display represents the last observation until
a newer selection or a session/log boundary. Technical names and party-marker IDs are not guessed into labels.

## FE compatibility and work on Mac

No decoder change should be necessary: the wire shape is unchanged. The current ServerSession merges a
QT-only delta with the full snapshot; ShipContextTracker mirrors qtTarget even without a ship revision change.
DeckState stores the resulting target independently of whether the Deck is enabled.

The Quantum readout is currently inside the Deck UI. A disabled Deck can therefore hide a valid QT value.
Manual Enable Deck may still be needed after returning to PU without a channel join. Choosing a local QT
target does not automatically enable Deck in this BE-only change.

Required checks/updates on Mac:

1. Update shared spec section 41: replace the bound-ship QT requirement and unconditional ship-transition
   resets with the owner's semantics above. Preserve all unrelated ship/ATC/input rules.
2. Add FE tests for a QT-only delta while ship is null, noShip/unknown status, unchanged context revision,
   latest-selection replacement, preservation across ship transitions, and clearing on PU/game/log end.
3. Confirm that disconnect hides the readout and reconnect's full snapshot restores the observed target.
4. Update comments that say every ship transition resets QT. Treat the label as a last observed local
   selection; observedAt describes freshness. Do not label it as authoritative live ship telemetry.
5. Build and run Swift tests in the iPad simulator, then verify portrait/landscape and the in-game readout.

The owner separately asked about manual recovery after menu reentry. See
`SHIP-CONTEXT-MANUAL-RECOVERY-PROPOSAL.md`; that feature is a proposal and has not been implemented.

## Validation

BE Release compilation and the full 425-test suite passed. Regression coverage includes local QT without
channel/spawn/binding, mismatched existing ship ID, QT-only state delta, ship-transition independence,
session/log/process clearing, repeated menu exits, exclusion of non-local records and safe target bounds.
Mac compilation and FE runtime behavior have not been verified on this Windows machine.
