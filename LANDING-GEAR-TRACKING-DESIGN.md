# Landing-gear tracking: FE ownership and ship lifecycle

> **Note ([FIX-07](FIX-07-one-path-deck-and-theme.md), spec 41.23, 2026-10-28):** ClearDriver no longer disables the Deck; the Deck turns off on `channelLeft` / `vehicleDestroyed` / `gameEnded` / `logReset`, and keys start and reset with the landing gear lit. Rows below that assume a ClearDriver Deck transition need revisiting before implementation.

Date: 2026-10-27

Status: agreed architectural direction and proposed behavior; not implemented by this document.

## Purpose

Remember an estimated landing-gear position while keeping the Windows companion small and inexpensive to run.
Leaving the pilot seat should switch the iPad deck off without erasing the ship's gear estimate. Returning to the
same ship should restore that estimate unless a new retrieval cycle or loss of continuity invalidated it.

This is a design note, not an instruction to implement changes automatically. Protocol v2 in section 41 of
`Claude outputs/CSMFD-discussion.md` remains the current contract. Any required contract extensions must be
specified and tested on both repositories before implementation.

## Responsibility split

| Windows server (BE) | iPad app (FE) |
|---|---|
| Read Game.log through the existing reader | Own estimated gear position and its confidence |
| Parse relevant ship lifecycle observations | Associate estimates with a vehicle and retrieval cycle |
| Report observed facts with sufficient identity and ordering | Initialize, retain, suspend, or invalidate estimates |
| Execute allowlisted commands and acknowledge their outcomes | Toggle the estimate once after a successful gear command |
| Retain input safety, watchdogs, cancellation, and key release | Own deck visibility, indicators, animations, and manual correction |

The BE reports facts; the FE interprets them for this feature. No BE gear-toggle simulator is required.
The BE may retain the small lifecycle summary necessary for a correct full snapshot and reconnect handling.
It must not need to preserve the FE's estimated gear position.

## Why this keeps PC work small

Extend the existing log pipeline with cheap marker checks and narrowly scoped parsing. Send compact updates when
relevant observations change. Reuse the existing transport, state coalescing, and command acknowledgments.

Do not add another log reader, physical-key polling, a global keyboard hook, periodic gear calculations, or PC-side
UI animation work for this feature. Lifecycle changes needed by the FE must survive state coalescing, either in a
durable lifecycle revision/summary or a separately specified delivery mechanism. Do not assume every intermediate
state delta reaches the client.

The computational cost of remembering one gear value is small on either device; the meaningful performance choices
are avoiding extra continuous work and bounding parsing, memory, and network traffic. Actual FPS/frametime impact
must be measured in game rather than inferred from this design.

## Separate display state from remembered vehicle state

Display/control state includes whether the deck is enabled, active hold animations, transient feedback, and
self-destruct arming. It can reset when the player leaves the seat.

Remembered vehicle state includes vehicle identity, retrieval-cycle identity, last estimated gear position, and
whether the estimate is usable or uncertain. It must survive display resets and manual deck re-enabling.

Suggested conceptual values:

- Gear position: `unknown`, `down`, `up`.
- Estimate quality: assumed/tracked, or uncertain.
- Vehicle association: server/game-session identity plus vehicle EntityId when available.
- Retrieval cycle: a separate generation/revision, not merely the EntityId or current control-context ID.
- Observation continuity: whether the FE could have missed relevant lifecycle changes or command outcomes.

These are conceptual fields, not a finalized Swift model or wire schema. Keep estimation rules in a pure,
testable FE reducer/tracker; the views render its results. Protocol/session validation remains in the network layer.

## Starting assumption

A freshly retrieved ship arriving on its platform is a strong practical basis for assuming gear down. Correlate
retrieval information with the matching ship/channel before initializing the estimate. This assumption is useful
product behavior, not measured gear telemetry.

Initialize down once per recognized retrieval cycle. A repeated channel notification, return to the seat,
duplicate spawn record, or enrichment of the same record must not initialize it again.

Spawn information can describe an attempted/in-progress retrieval. The precise rule for recognizing a new retrieval
cycle, including duplicate notifications, still needs validation with a controlled store/retrieve test. If identity
or cycle association is ambiguous, retain an uncertain/unknown state rather than assigning another ship's estimate.

## Behavior

| Event | Display/input behavior | Remembered gear behavior |
|---|---|---|
| New correlated retrieval and ship association | Enable according to the deck policy | Initialize down, assumed, once for that cycle |
| CSMFD landingGear action acknowledged as sent | Normal command feedback | Toggle once if the starting estimate is usable |
| Rejected, ignored, or locally unsent action | Existing failure feedback | Do not toggle |
| Lost acknowledgment / unknown outcome | Show uncertainty; never replay input | Mark estimate uncertain |
| Matching local ClearDriver | Disable deck, release input, stop holds, disarm self-destruct | Keep remembered gear for that vehicle |
| Return to the same vehicle without a new retrieval cycle | Enable when a suitable signal or manual action is available | Restore remembered gear |
| Matching stow-attempt observation | Suspend association as appropriate | Mark the cycle suspended/uncertain; do not assert storage success or reset to down |
| Strong destruction evidence for that vehicle | Disable affected active deck | End that vehicle's estimate |
| New retrieval cycle, including reuse of the same EntityId | Apply normal association policy | Replace the old cycle and initialize down, assumed |
| Other ship becomes active | Show the other ship | Keep estimates isolated; do not copy the previous ship's state |
| Game session ends, server restarts, or log continuity is lost | Apply existing disconnection policy | Invalidate continuity; require a new baseline or manual correction |
| User chooses Mark gear down/up | No input sent to the game | Set the estimate explicitly |

If position is unknown, a toggle alone cannot establish whether it became up or down. Keep it unknown until a new
baseline or manual correction. Associate command outcomes with the original vehicle/cycle so a delayed acknowledgment
cannot modify a newly selected ship. Count each command once; UP acknowledgments must not toggle gear again.

Track the semantic `landingGear` action, not the raw N key: auto-land also uses N but is a different action.
A sent acknowledgment confirms server-side input execution, not successful execution of the intended action in game.
Physical keyboard/HOTAS input and another pilot's gear changes are not observed by this design. Preserve the
estimated nature of the indicator and offer correction without sending another toggle.

## Reconnect and app lifecycle

The FE can miss events while disconnected or backgrounded. Retaining a value in memory does not establish continuity.
After reconnect, use the server's full snapshot and lifecycle identity to decide whether an estimate can resume.
The current protocol must not be assumed to provide sufficient lifecycle history for that decision.

If continuity cannot be established, show the remembered value as uncertain or use unknown. Do not silently restore
a trusted gear indication. An initial implementation can avoid persistence across app restarts; if persistence is
added later, stored estimates must remain uncertain until reconciled. No automatic command retries are permitted.

## Evidence from the available logs

A read-only scan on 2026-10-27 covered 34 archived logs plus the current Game.log: 35 files and 2,600,717 lines,
from available sessions dated 11-26 October. Counts and absence claims apply only to this corpus.

### Stow attempts associated with the requested ships

Paths below are relative to the game's `LIVE/logbackups` directory. Times are Paris local time.

| Ship | Time | EntityId | Archive and line |
|---|---|---|---|
| Aurora | 17 Oct 19:54:06 | 885833539128 | `Game Build(12913470) 17 Oct 26 (18 11 07).log`, 16273 |
| C1 | 17 Oct 21:23:35 | 887352519215 | Same archive, 29261 |
| RAFT | 19 Oct 00:19:50 | 890440040248 | `Game Build(12913470) 18 Oct 26 (21 26 45).log`, 10015 |
| Vulture | 22 Oct 23:18:07 | 891103312348 | `Game Build(12913470) 22 Oct 26 (20 38 01).log`, 15156 |

Each uses `LandingArea_UnregisterFromExternalSystems_StowingVehicle`, says it is attempting to stow a vehicle
because the landing area is unregistering, and includes `IsAuthorityPossible [0]`. Vehicle IDs were correlated with
local-control/retrieval records. These observations are not universal successful-storage acknowledgments.
`ATC_Reset_VehiclesBeingStoredCleared` is an internal-list reset, frequently with zero entries; it is not a storage endpoint.

### Destruction

- Aurora 872969214881: `Game Build(12881860) 11 Oct 26 (22 26 36).log`, lines 8740, 8741, 8747:
  FatalCollision, matching local ClearDriver, and local actor ejection from a destroyed vehicle. Paris time:
  11 October 23:50:53. Two additional Aurora collision/destruction sequences were found.
- RAFT 890083256632: `Game Build(12913470) 19 Oct 26 (00 48 26).log`, lines 10924, 10926, 10927:
  the same sequence. Paris time: 19 October 03:15:01. A subsequently controlled RAFT has a different EntityId.
- No equivalent locally associated C1 or Vulture destruction sequence was found in this scan. These records are
  not guaranteed for every destruction, especially when the player is absent. Never reset the selected ship from
  a destruction message belonging to another vehicle.

### EntityId reuse across retrievals

Aurora 892051574440, `Game Build(12913470) 20 Oct 26 (21 11 46).log`:

- Line 37347: spawn information, 2026-10-20T23:42:05.064Z.
- Line 45817: stow attempt, 2026-10-21T00:34:15.478Z.
- Lines 46059 and 46062: new spawning/spawned information for the same ID, 00:36:32.491Z and 00:36:33.968Z.

The Vulture also has repeated spawn-information records for 891103312348 before and after its stow attempt.
This supports distinguishing retrieval cycles from vehicle identity; it does not by itself finalize cycle detection.

## Current code and integration gaps

- `CSMFD/Deck/DeckState.swift`: `applyShipContext` and `enableManually` clear toggle lights. Separate gear memory
  from these presentation resets. Preserve input release and self-destruct disarming.
- `CSMFD/ContentView.swift` / `CSMFD/Network/ServerConnection.swift`: in the inspected checkout, no consumer is
  assigned to `onState`; state messages are stored without merging deltas into a full snapshot. The live state-to-deck
  integration remains a prerequisite, covered by FIX-02.
- BE `GameLogProcessor`: ClearDriver clears the active ship, and a channel join creates a new control context.
  Retained vehicle identity must survive those changes. The control-context ID is not the retrieval-cycle ID.
- ClearDriver is a control-token-release event, not a verified ship-channel-leave event. Repeated ClearDriver
  observations occur without a corresponding new channel join for every later control interval. Reliable automatic
  return-to-seat detection is unresolved; manual deck enable must be able to restore retained gear memory.
- The Vulture channel name contains `Teach's Special`; the current BE channel regex excludes apostrophes in ship
  names. C1 channel `Crusader C1 Spirit` and model `CRUS_Spirit_C1` have different word order for the existing
  normalization/matching rule. Address these association gaps before relying on the generic rules for these ships.
- New lifecycle fields/events are proposed work, not existing protocol messages. Update the v2 specification,
  DTOs/writer/parser, reference fixtures, and both test suites together when the contract is chosen.

## Validation before release

Use deterministic FE tests for retrieval initialization, duplicate suppression, command outcomes, delayed acknowledgments,
seat exit/re-entry, manual enable, ship switching, stow uncertainty, destruction, reconnect, and same-ID retrieval cycles.
Use existing BE test infrastructure for new event parsing and any lifecycle summary, keeping real input out of tests.

Run a controlled game session: retrieve, associate, toggle gear, leave/re-enter the seat, store, retrieve again, then
disconnect/reconnect. Record action times and compare against logs. Validate the starting-down assumption and retrieval
boundaries. Exercise the Aurora, C1, RAFT, and Vulture name/identity cases. Measure server CPU, memory, and in-game
frametime impact with the feature enabled and disabled.

This document adds no runtime functionality and changes no input or security behavior.
