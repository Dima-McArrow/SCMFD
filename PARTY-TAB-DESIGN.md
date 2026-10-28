# Party tab: observed events, FE ownership, and BE requirements

> **Note ([FIX-07](FIX-07-one-path-deck-and-theme.md), spec 41.23, 2026-10-28):** ClearDriver no longer disables the Deck; read "when ClearDriver disables the Deck" below as "when the Deck is off outside a ship channel".

Date: 2026-10-27

Status: original design proposal; the observed Party MVP is now implemented in source (2026-10-28), spec 41.24.
Mac simulator build/tests and in-game verification are pending. The evidence and limitations below remain design context.
This note records the requested Party tab. It is not an instruction to make runtime changes automatically.
Protocol v2 section 41 of `Claude outputs/CSMFD-discussion.md` remains the current wire contract.

## Product behavior

Add a Party tab independent of the ship Deck. It remains available outside a ship and when ClearDriver disables
the Deck. Apply the app's current presentation theme, including the neutral default described in
`DEFAULT-THEME-DESIGN.md`, without resetting party data when the theme changes.

A first version can display:

- A timestamped activity feed: invites, local creation/join, member joins/leaves, disbanding, leader changes and launch activity.
- Last observed party status, with an explicit unknown/stale state when observation continuity is lost.
- Observed member names; label the list as potentially incomplete until a complete roster source is validated.
- Last observed leader and launch notifications.

An empty observed list must not be shown as proof of no party. A party invite notification is not proof of membership.
Historical notifications must not be presented as current membership without reconciliation.

## Evidence

A read-only scan of 35 available logs (34 archives plus current Game.log, approximately 2.6 million lines,
available sessions from 11-26 October) found the following actual SHUDEvent_OnNotification additions.
Multiline bodies were assembled; queue reprints and UpdateNotificationItem changes were not counted again.
These are observed additions, not guarantees of complete event coverage.

| Notification | Count | Available information |
|---|---:|---|
| Party Invite Received: Accept Invitation? | 6 | Inviter's name on the preceding line |
| You have joined / party | 5 | Local membership began; not a full roster |
| You have created / party | 1 | Local party creation |
| New Member Joined | 5 | Name in `name has joined the party` |
| Member Left | 9 | Name in `name has left the party` |
| Party Disbanded | 3 | Party ended |
| New Party Leader | 3 | Name in `name is now party leader` |
| Party Launch | 10 | Initiating leader, or notifications sent |
| Party Launching: Join Party In PU? | 1 | Prompt and initiating name |
| Party Launch Accepted | 4 | Acceptance notification; names are corrupted in these examples |

Total: 47 relevant notification additions. Ignore incidental references such as incapacitation help text and
the Party Favors commodity. Do not repair corrupted names by guessing.

Example evidence, relative to the game's `LIVE/logbackups` directory:

- `Game Build(12913470) 24 Oct 26 (04 48 48).log`, lines 22871, 22997, 23070: L-Qing joined, left,
  then joined again at Paris times 07:28:40, 07:29:11 and 07:29:34 on 24 October.
- `Game Build(12913470) 18 Oct 26 (18 26 39).log`, lines 5581, 5587, 5592, 8477: invitation,
  structured acceptance action, local join, and later disbanding.
- `Game Build(12913470) 26 Oct 26 (02 02 51).log`, lines 741, 743, 7270, 10092: a structured
  leadership-transfer action and named leader notifications, including the local player becoming leader.
- `Game Build(12913470) 25 Oct 26 (21 49 56).log`, lines 14519, 15721, 16797, 16852:
  launch acceptance notifications with damaged name text.

Other structured observations include 5 Accept invitation actions, 50 CPartyMarkerComponent RWES streamed-in
markers, 44 CPartyMarkerComponent UFES streaming-out markers, 1 Transfer group leadership action and 5
structured party-launch records. Marker records carry marker ID and TrackedEntityId, including the local player.

Streaming out a marker does not prove a member left, disconnected, died, or moved a particular distance.
Use explicit membership notifications for membership updates. Display names and entity IDs must not be merged
without a validated mapping; displayed names differ across some records.

Leave group, Set Member Ready Status, SyncSquadMembers and a matchmaking party UUID also appear, but the
inspected examples are Arena Commander/lobby-related. Do not generalize them to Persistent Universe party state.
Update group cache Start/Success messages do not themselves provide a complete roster or a membership change.
DirectMessage groups and building/lobby asset names are unrelated to party membership.

## FE / BE split and readiness

The MVP now emits six bounded Party facts through ActivityJournal and the existing authenticated activity
transport (41.24). No Party roster or summary is computed on the BE. The FE owns PartyState and PartyView.

BE additions should remain small: parse a selected set of normalized facts through the existing reader, assemble
multiline notifications, suppress display reprints, and publish bounded observations or a specified state summary.
Do not add a second reader, player polling or game-memory access. Retain only enough party identity/revision and
summary information to make snapshots and reconnect semantics correct. An ephemeral event must not disappear
unnoticed through ordinary ship-state coalescing.

The FE owns the party reducer, observed member list, history presentation, uncertainty labels and animations.
Pure rules should be testable outside SwiftUI. All user-facing strings use the existing en/fr/ru string catalog.

Define the party wire contract before implementation: session identity, ordering/deduplication, full snapshot
versus event semantics, bounded history, group identity when actually available, and completeness/confidence.
Coordinate the v2 spec, BE parser/writer/state, fixtures, FE DTOs/session handling and both test suites.

Current input commands do not include party controls. A log hook is not an API to invite, accept, decline,
leave, kick or promote. Those actions are outside this initial read-only tab.

## Lifecycle and uncertainty

Party state is independent of pilot-seat state, ship-channel membership, manufacturer selection and remembered
landing gear. ClearDriver, entering/leaving a ship channel, or changing theme must not clear the Party tab.

A tailer starting at EOF misses earlier membership changes. Reconnect, shard change, log reset, process restart
and app backgrounding can break continuity. Keep history separately from current-state confidence; do not
restore a trusted roster from old records. If no complete roster can be established, show observed names rather
than claiming an authoritative member count.

No complete roster snapshot, general all-member online status, live positions/distances, health, current ships,
gear states or kick-specific reason was established by this scan. Absence in this corpus is not proof that the
game never logs those facts.

## Verification

Test multiline assembly, duplicate suppression, damaged text, invite versus join, member add/remove, leader
changes, disband, partial membership, reset/reconnect, and feed bounds with saved fixtures and deterministic FE tests.
Keep the current server logging/privacy rules; extracting approved display names for the paired FE does not
authorize raw social-log dumps or player-name logging in diagnostics.

Run a controlled session with several players: create, invite, accept, decline, join, leave, kick, transfer
leadership, launch, disband, reconnect and change shard. Record known actions and the roster before/after each.
In particular, determine whether all pre-existing members are named when the local player joins an existing party.
Do not promise a complete live roster until that is demonstrated.
