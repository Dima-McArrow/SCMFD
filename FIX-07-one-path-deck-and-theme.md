# FIX-07 · One path for the Deck and the theme: the ship channel

| | |
|---|---|
| Size | M |
| Depends on | nothing; replaces the theme parts of FIX-02 / FIX-04 and the channel part of 41.22 |
| Decision | owner, 2026-10-28 (see "Why") |
| Server side | done: SCMFDBE `ffff70f` (channelLeft, ClearDriver no transition), `9064f12` (vehicleDestroyed), `cc0cd1c` (no channel events in activity) |
| iPad side | implemented 2026-10-28, steps 1-6 (commit `ee5f97f`); follow-up 2026-10-28: tolerant server enums and every SCMFDBE fixture pinned in `ProtocolV2Tests`. Last full run 2026-10-28 on iPad Pro 13-inch (M5) simulator: 156 tests, 251 runs (parameterized arguments counted separately), all passed. Live test against SCMFDBE and in game pending |

### Implementation notes (iPad)

- `ShipContextStatus.reason` stays the raw string (Debug shows what the server sent); `knownReason` maps it,
  unknown values to `.unknown` (same pattern as `ServerAck.reason` / `rejectReason`).
- `ShipContextTracker` emits `DeckUpdate.theme: ThemeChange?` tagged with `(sessionId, revision)` and
  `resetKeys` (only `vehicleDestroyed`). `ContentView` has one `onChange(of: deck.lastThemeChange)`.
- `clearDriver` from an older server still bumps the revision; the tracker keeps the Deck as it was and moves a
  manual enable to the new revision, so it does not count as a transition. Mirrored readouts (ship name, QT, ATC)
  still follow the server.
- The manual enable is tied to `(sessionId, revision)` only, not to the connection, so it survives a reconnect.
- Reset Deck is the `arrow.counterclockwise` icon next to Settings; `DeckState.defaultLit = [.landingGear]`.
  `resetLights()` was renamed `resetDeck()`; the Settings "Reset button lights" button was removed (one reset).
- The Deck starts off in every mode, the unpaired console link included (table, first row):
  `DeckState.isShipDisconnected` starts `true`, taps on the off Deck are ignored, and Enable Deck without a server
  context uses the local fallback in `DeckState.enableManually()` (keys kept). Previews that show keys enable it.
- `ManufacturerTheme.label(_: String)` became `label(verbatim:)`. With both an unlabeled `String` and a
  `LocalizedStringResource` overload, a string literal picked the `String` one, so `theme.label("Deck")`, the key
  states (On/Off, Ready, Engaged…), the QT readout and the tab titles were never localized; Missions / Finances /
  Debug (`MFDPage.shortTitle`, a plain `String`) had no catalog entry at all. Now a literal always localizes and
  already-final text must say `verbatim:`.
- Tests: `ShipContextTrackerTests`, `DeckStateTests`, `AppThemeTests`, `ProtocolV2Tests` (fixtures compacted
  from SCMFDBE, same JSON values; client fixtures compared as JSON objects, a missing `mods` counts as `[]` per the
  spec), `LegacyShipChannelEventTests` (old history stays readable).
- Server enums decode an unknown value into `.unrecognized(word)` (`LenientWireEnum` in `ProtocolV2.swift`), the
  same bug class as `shipContext.reason` before this fix: a strict enum threw, `ServerConnection` reported
  `.protocolViolation`, and that never reconnects. The word is kept (Debug prints `wireValue`, i.e. what the server
  sent) and the case is typed, so every `switch` must handle it. Readings: `ShipContextStatus.Status` → Deck stays
  off unless enabled manually (only `assumed` enables it; the server's own `"unknown"` stays a separate case),
  `Confidence` → read like `.stale`, `QuantumTargetStatus.Mode` → shown like `.unknown`, `HangarRequestStatus` →
  "no data" (`ShipContextTracker` makes it nil, never `idle` or an answer), `LogStatus.Status` → Debug only,
  `ServerAck.Status` → `CommandOutcome.unknown` (never `sent`, never retried). A wrong JSON type is still malformed.
- Test target fixes needed to build at all (the target did not compile at `68b7bbc`): the ack-deadline tests
  (`missingAckClosesEvenWhileServerMessagesKeepArriving`, `acknowledgedCommandDoesNotLeaveADeadlineBehind`) moved
  out of `ReconnectBackoffTests` into `ServerSessionTests`, where their helpers live; `InputReliabilityTests` no
  longer wraps mutating `KeyPressTracker` calls in `#expect` (the macro captures the receiver immutably).

### Server follow-up (SCMFDBE, not done here)

After `ffff70f` the server never produces `ShipContextReason.ClearDriver`: in `src/` it only appeared in the enum
(`Csmfd.Protocol/StateModel.cs`) and in `ServerMessageWriter.ToWire` (`=> "clearDriver"`), and the fixture
`server-state-delta-clear-driver.json` (written by `ServerMessageWriterTests.WritesClearDriverDeltaFixture`)
described a message the current server cannot send.

Owner decision: the server removes `ShipContextReason.ClearDriver`, its `ToWire` arm, the writer test and
`server-state-delta-clear-driver.json`. The iPad keeps ignoring `"clearDriver"` (an older server may still send
it), and `ProtocolV2Tests.clearDriverDelta` stays as an inline "older server" sample.

## Why

The theme stayed on default in the 2026-10-28 game test although the server sent `shipContext.reason:
channelJoined` with `manufacturerPrefix: "ANVL"` / `"DRAK"`. Two paths fed the theme: `shipContext` (state) and
`shipChannelJoined/Left` (activity), and `hasChannelThemeEvidence` let the activity path silence the state path.
The activity events were never produced from real logs, and `sessionEnded` counted as evidence, so the theme
was stuck. Decision: **one path, the `state` message**. Activity is only for rewards and contracts again.

## Behaviour

The ship context is `(sessionId, shipContext.revision)`; a new pair is a transition. Theme changes happen only
with **Auto theme** on; with it off the user's pick is never touched.

| `shipContext` | Deck | Theme (Auto theme on) | Keys (lit state) |
|---|---|---|---|
| App start, not connected yet | off | SCMFD (standard) | defaults: **landing gear lit**, all others off |
| `channelJoined` | **on** | manufacturer of `manufacturerPrefix` (unknown prefix: unchanged) | **kept**, also for a different ship |
| `channelLeft`, `gameEnded`, `logReset` | **off** | SCMFD | **kept** |
| `vehicleDestroyed` | **off** | SCMFD | **reset to defaults** (landing gear lit, self-destruct disarmed) |
| `clearDriver` (only from an older server) | ignored | ignored | ignored |
| `startup` / status `unknown` on connect | off | unchanged | unchanged |
| Same revision again (delta, reconnect, enrichment) | from `status`, or the manual enable | unchanged | unchanged |
| Transport lost | unchanged | unchanged | unchanged |
| Unknown future reason | from `status` (`assumed` on, otherwise off) | unchanged | unchanged |

- **Enable Deck** button directly on the off screen (`DisconnectedDeckView`, where "No ship connection" is),
  one tap. It sends nothing to the game. It lasts until the next transition (new revision or sessionId) and is
  never persisted. Remove "Enable Deck manually" from Settings (`ThemePickerView`).
- **Reset Deck** as a small icon in the top bar / menu: keys back to defaults (landing gear lit), self-destruct
  disarmed. Local only, sends nothing to the game.
- Why the Deck goes off outside a ship channel: on foot `mouse1` fires the weapon in hand and a held `Backspace`
  kills the character, so the ship keys must not be one accidental touch away.

## Changes

1. **Decoding** (`Network/ProtocolV2.swift`): `ShipContextStatus.Reason` must not fail on an unknown value (today
   a new reason would be a decoding error, i.e. a protocol violation and a reconnect loop). Add `vehicleDestroyed`
   and an `unknown` fallback (e.g. `init(from:)` mapping unrecognised strings to `.unknown`).
2. **`Deck/ShipContextTracker.swift`**: replace `DeckUpdate.join: ShipJoin?` with a theme instruction for the
   transition, e.g. `theme: ThemeChange?` = `.manufacturer(m)` on `channelJoined`, `.standard` on `channelLeft` /
   `gameEnded` / `logReset` / `vehicleDestroyed`, `nil` otherwise; tag it with `(sessionId, revision)` so
   SwiftUI's `onChange` fires once per transition. Replace `resetLocalState` with `resetKeys`, true only for
   `vehicleDestroyed`. `clearDriver` is a transition the tracker swallows (no Deck, theme or key change).
   Manual enable: valid while `(sessionId, revision)` is unchanged.
3. **`Deck/DeckState.swift`**: default `lit = [.landingGear]`; `resetLights()` resets to that default (it is also
   the Reset Deck action). `apply` no longer resets keys except on `resetKeys`.
4. **`ContentView.swift`**: one `onChange` for the tracker's theme instruction (guarded by `autoTheme`). Remove
   the `activity.channelThemeChange` handler and the `!activity.hasChannelThemeEvidence` guard.
5. **Delete** `Theme/ShipChannelThemeTracker.swift` and its tests; remove `channelThemeChange`,
   `hasChannelThemeEvidence` and the tracker from `Activity/SessionActivityStore.swift`. Keep decoding an optional
   `channelId` and the `shipChannel*` kinds in saved history so old history files stay readable; they are ignored.
6. **Strings**: "Enable Deck", "Reset Deck" (accessibility label of the icon) with fr / ru.

## Tests (Swift Testing)

Use the server fixtures `server-state-full.json`, `server-state-delta-clear-driver.json` and the new
`server-state-delta-vehicle-destroyed.json` (SCMFDBE `tests/Csmfd.Tests/Fixtures/Protocol`).

> **Note (2026-10-28):** `server-state-delta-clear-driver.json` was removed on the server (41.23: `clearDriver` is no
> longer sent). The iPad keeps it as the inline "older server" sample `ProtocolV2Tests.clearDriverDelta`.

| Input | Expected |
|---|---|
| Fresh `DeckState` | landing gear lit, nothing else |
| `channelJoined` `DRAK`, Auto theme on / off | Deck on; theme Drake / unchanged |
| `channelJoined` while keys are lit | keys kept |
| `channelJoined` of another ship (`ANVL`) after `channelLeft` | Anvil theme, keys kept |
| `channelLeft` | Deck off, theme SCMFD, keys kept |
| `vehicleDestroyed` fixture | Deck off, theme SCMFD, keys reset (landing gear lit) |
| `clearDriver` fixture (older server) | nothing changes |
| Manual enable → same-revision delta | stays on; next transition decides again |
| Reason `"somethingNew"` | decodes; Deck from `status`; theme and keys unchanged |
| Reset Deck | landing gear lit, others off, self-destruct disarmed |

## Out of scope

Ship stored at a terminal / in the hangar: no verified Game.log line yet. It will become another reason after a
controlled in-game test (store the ship, note the time). Until then only `vehicleDestroyed` resets the keys.
