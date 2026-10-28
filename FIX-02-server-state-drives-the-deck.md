# FIX-02 · Server state drives the Deck (ship context, ClearDriver, manual override)

> **Superseded in part by [FIX-07](FIX-07-one-path-deck-and-theme.md) (spec 41.23, 2026-10-28):** ClearDriver is no longer a Deck transition, keys are no longer reset on every transition (only on `vehicleDestroyed` or Reset Deck), and the manual enable is tied to `(sessionId, revision)` only, so it survives a reconnect. The rest (merged snapshots, transport loss is not a transition) still holds.

| | |
|---|---|
| Size | L — the biggest open FE item |
| Depends on | nothing; FIX-03 and FIX-04 build on it |
| Spec | 41.8 (state, seq, deltas), 41.9 (ship, ClearDriver, manual override), 41.17, 41.18 (acceptance rows) |
| Server side | done: full state after `welcome`, deltas with `seq`, `shipContext.revision` |

## Problem

- The server already sends a full `state` after `welcome` and deltas afterwards. `ServerSession` checks `seq` and
  the full-first rule, then `ServerConnection` stores the **raw message** in `latestState` (a delta overwrites the
  full snapshot, so the Debug tab shows only the last delta) and calls `onState`, which **nobody sets**.
  Result: the Deck never reacts to entering a ship, ClearDriver or the game ending.
- `DeckState.applyShipContext(name:)` resets lights, QT, ATC and self-destruct arming on **every** call. Calling it
  per delta or for an identical snapshot would wipe local state and the manual override (41.17, last bullet).
- `DeckState.enableManually()` is not tied to anything. Per 41.9 a new ClearDriver must cancel it, while an
  identical snapshot of the same revision must not.

## Target behaviour

1. **One merged snapshot per connection.** Full state replaces it. Delta: a missing key keeps the value, a present
   key replaces the whole object (no deep merge), `"ship": null` (`StateField.value(nil)`) clears the ship.
   Reset the snapshot when a new connection starts (`ServerConnection.start` already sets `latestState = nil`).
   Make `latestState` hold this merged snapshot so the Debug tab shows the real state too.
2. **Transition** = `(sessionId, shipContext.revision)` differs from the last applied pair. On a transition:
   reset lights and self-destruct arming, clear local QT/ATC, drop the manual override, then set
   *Deck enabled* = `shipContext.status == .assumed`. The theme is not touched here (FIX-04).
3. **Same `(sessionId, revision)`**: only update the ship label (`ship.name`; enrichment of model/entityId arrives
   this way). Never reset lights, never re-enable the Deck.
4. **Manual override** (`Enable Deck manually`): remember `(sessionId, revision, connectionId)`.
   *Deck enabled* = `status == .assumed` **or** the override matches the current triple. The override is dropped on
   a transition, on disconnect / a new `connectionId`, on a new `sessionId` and on app restart. Never persist it.
   It sends nothing to the game.
5. **Transport loss is not ClearDriver.** Do not disable the Deck on disconnect; keys already resolve as
   `.notSent(.notConnected)` (*No server link*). After reconnect the full snapshot is applied with the rules
   above; with the override gone, a `noShip` context disables the Deck again and the user can re-enable it.
6. **`unknown` / `startup`** (server started while already in the cockpit, 41.14): Deck off with
   *No ship connection*; the user enables it manually.
7. **Not paired** (console link): keep today's playground — Deck usable, no snapshots.

## Suggested shape

- A pure `nonisolated struct` (e.g. `ShipContextTracker` in `SCMFD/Deck`) holding the merged snapshot, the last
  applied `(sessionId, revision)` and the override. Input: a `ServerState` plus the current `connectionId`
  (from `SessionPhase.ready(welcome)`). Output: a small value such as
  `DeckUpdate(enabled: Bool, shipName: String?, resetLocalState: Bool)`.
- `DeckState` applies the update; `applyShipContext(name:)` goes away or becomes preview-only
  (`DisconnectedDeckView` and `ThemePickerView` previews use it today).
- Wire it in `ContentView`: set `server.onState` once, next to `NetworkCommandLink`. Keep protocol decisions out of
  the views (CLAUDE.md: they belong in tested pure types).

## Tests (Swift Testing)

Each row is one test; build states inline or decode the server fixtures
`SCMFDBE/tests/Csmfd.Tests/Fixtures/Protocol/server-state-full.json` and `server-state-delta-clear-driver.json`
(copy them into `SCMFDTests` if useful).

> **Note (2026-10-28):** `server-state-delta-clear-driver.json` was removed on the server (41.23: `clearDriver` is no
> longer sent). The iPad keeps it as the inline "older server" sample `ProtocolV2Tests.clearDriverDelta`.

| Input | Expected |
|---|---|
| Full state, `assumed`, ship *Drake Cutter Rambler* | Enabled, label set, reset once |
| Delta with only `qtTarget` | No reset, lights kept |
| Delta with `ship` enriched, same revision | Label updated, lights kept, no reset |
| ClearDriver delta (`ship: null`, revision + 1, `noShip`) | Disabled, local state reset |
| Manual enable → identical full snapshot (same revision) | Stays enabled |
| Manual enable → new ClearDriver (revision + 1, still `noShip`) | Disabled, override dropped |
| Manual enable → disconnect → reconnect, same revision, `noShip` | Disabled (override gone) |
| New `sessionId` with the same revision number | Treated as a transition |
| Join → ClearDriver while the channel stays active (no new join) | Stays disabled |

## Out of scope

QT readout and ATC indicator (FIX-03), auto theme (FIX-04), any new message type. No `takeControl` command exists
in v2: the server never confirms a seat.
