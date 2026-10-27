# FIX-03 · Quantum target readout and ATC indicator from server state

| | |
|---|---|
| Size | S |
| Depends on | FIX-02 (merged snapshot and transitions) |
| Spec | 41.8 (`qtTarget`, `hangarRequest`), 41.13 (ATC meaning) |
| Server side | done: `destination` from the verified QT line; ATC `pending` / `answered` / `timeout` with watermark |

## Problem

`QuantumTargetReadout` and the ATC row on `DeckPage` read `DeckState.quantumTarget` and `DeckState.hangarRequest`,
which only previews set. The values the server already sends (`qtTarget`, `hangarRequest`) never reach them.

## Change

1. **QT** — map `QuantumTargetStatus` to `DeckState.quantumTarget`:

   | Server | Deck |
   |---|---|
   | `mode: unknown` (always `confidence: stale`, names null) | `.unknown` |
   | `mode: destination` | `.destination(displayName ?? internalName)` — the UI prefers `displayName` (41.8) |
   | `mode: freeMode` | `.freeMode` (the server does not emit it yet: no verified Game.log line) |

   Today the server sends `displayName: null` and a technical `internalName`; show it as is, no prettifying guess.

2. **ATC** — `DeckState.hangarRequest = hangarRequest.status` whenever a snapshot exists. `nil` keeps meaning
   *no server data* (not paired / no snapshot yet); a connected server in `idle` shows *No active request*.
   - `pending` only comes from the server, after the `requestLanding` key-down was really sent. Never set it locally
     on tap.
   - `answered` stays until the server changes it; no FE timer clears it.
   - `timeout` shows *No confirmation · Retry*; no automatic retry.
   - `answered` does not mean clearance, open doors or a hangar number (41.13); keep the current wording.

3. Both fields are server-reset on ClearDriver / new context (the delta carries `qtTarget: unknown` and
   `hangarRequest: idle`), so the FE only mirrors them. The local reset from FIX-02 covers the moment between a
   transition and the next value.

Put the mapping in a pure function next to the FIX-02 tracker so it is unit-tested; views stay dumb.

## Tests (Swift Testing)

- `unknown` → `.unknown`; `destination` with only `internalName` → that name; with both → `displayName`.
- Each `hangarRequest.status` maps to the same `HangarRequestStatus`; no snapshot → `nil`.
- ClearDriver fixture (`server-state-delta-clear-driver.json` in SCMFDBE) → QT `.unknown`, ATC `.idle`.

## Out of scope

Server-side QT `freeMode` and `displayName` (needs real in-game log lines), ATC request ids (the log has none).
