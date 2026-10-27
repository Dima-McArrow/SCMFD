# Landing request: orange pending pulse and green response flash

Date: 2026-10-27

Status: requested FE presentation behavior; BE tracking already implemented. This document does not implement
the animation or the pending ship-state-to-Deck integration.

## Requested behavior

After a landing/takeoff request is successfully sent, pulse the button orange while awaiting an observed ATC
response. On a qualifying response, show green for one second, then restore the normal button appearance.

| Reported state | FE presentation |
|---|---|
| idle | Normal button appearance |
| pending | Orange pulse |
| answered | Green flash once for this request, lasting one second |
| timeout | Stop pulsing; show No confirmation / Retry |
| Command rejected or not sent | Existing rejection feedback; do not enter pending locally |

## BE readiness

The BE starts `hangarRequest.pending` after InputExecutor successfully sends the requestLanding down/hold input.
It records the command ID, ship context, log generation, file-length watermark and a 120-second deadline.

The existing parser recognizes the `Hangar Request Completed` notification. The processor changes the state
to answered only when a request is pending and the line is at/after the watermark in the same generation and
ship context. It reports timeout after 120 seconds without a qualifying response. Context transitions reset
tracking to idle. These states already exist in protocol v2; no new BE animation timer or input command is needed.

The observed response does not prove clearance, open doors, or a particular hangar assignment. The game
notification has no request ID, so a delayed response to an older request can still be attributed to a newer one.
Watermark/context checks reduce unrelated matches but cannot eliminate this ambiguity.

## FE implementation

Complete the merged state/Deck adapter in FIX-02 and the ATC mapping in FIX-03. Read `hangarRequest` from the
merged snapshot; missing delta fields preserve the previous value. Orange pending must follow BE state, not
an optimistic local tap or a sent acknowledgment alone.

The one-second green flash is presentation state owned by the iPad. Do not clear the server's answered state
when the animation ends. Deduplicate the flash by server-session identity plus request command ID, so repeated
snapshots/reconnect replay do not flash again for the same response. A new request interrupts any old flash.
Cancel presentation tasks when the control disappears or its request/context changes. Respect reduced motion.

If pending and answered are coalesced before delivery, the FE can receive answered directly and should still
flash green once for that new response. Repeated answered snapshots must not extend the flash indefinitely.
Never automatically retry a request. Show stale/disconnected feedback when the link drops; a saved state is not
proof of a newly received response.

## Verification on the Mac and in game

Test pending-to-answered, pending-to-timeout, rejected input, direct answered after coalescing, repeated snapshots,
new request during the flash, context reset and reconnect. Use a controllable clock/presentation controller for
the one-second behavior. Check the real request against Game.log and confirm orange/green appearance on iPad.

The session rewards/contracts implementation is separate and does not complete FIX-02/FIX-03 or this animation.
