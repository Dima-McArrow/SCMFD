# Design proposal: restore the last saved ship Deck state

Date: 2026-10-29.

Status: design only; not implemented. Revised after the owner's clarification. This revision replaces
the earlier identity-only/manual-enable proposal in this same file. FE source code is unchanged.

## Owner's intended behavior

The top-menu recovery button restores the complete last remembered configuration of the iPad Deck for
the ship the user is returning to. It is more than Enable Deck or restoring a ship name and theme.

Example: the user has landing gear down, lights on and engines off, leaves the seat, logs out or the game
client crashes. After returning to the same ship, the user presses the recovery button. The iPad restores
those exact remembered switch positions and the other saved persistent Deck indicators, then enables Deck.

This restores the last saved application state. Game.log does not establish all physical ship systems,
so it cannot guarantee that the actual ship still matches the snapshot. Mark recovered values as manually
restored/assumed and show the snapshot time. The user decides that this snapshot is appropriate.

The button sends no game commands. It must not press toggles to make the ship match the saved display.
Repeating a toggle could invert an already-correct physical system. Physical ship-state synchronization
is outside this proposal.

## Distinct actions

| Action | Meaning |
|---|---|
| Enable Deck | Makes the existing current Deck usable through the current local override |
| Reset Deck | Resets the current controls to the application's default presentation |
| Restore last ship state | Loads a saved Deck snapshot, including persistent switch positions, and enables Deck |

Use a separate top-menu recovery control, as requested. Its icon, label and placement should be designed
alongside the existing Reset Deck control, with localized accessibility labels and compact-width support.

## Snapshot contents

Keep all snapshot storage and calculations on the iPad. A small versioned value should contain:

- The paired server identity, last observed ship display name and any available model/context metadata.
- The saved persistent toggle/indicator state: the Deck's `lit` set, covering gear, lights, engine/power,
  shields and other controls that the app actually remembers as persistent presentation.
- The ship/manufacturer presentation context needed to identify the snapshot and optionally recover its theme.
- A saved-at timestamp and schema version.

Save the actual final app-side state rather than reconstructing it from defaults or a command history.
Capture changes after the existing successful-command/acknowledgment path has updated the Deck. A rejected
or unresolved command must not be recorded as a confirmed new switch position. A timeout cannot reveal what
the game actually did; retain existing outcome feedback and describe the snapshot as app state.

Do not promise recovery of state that was never observed or represented by the app. For example, a keyboard
change to gear or lights may leave the iPad's remembered state out of sync with the physical ship.

## Transient state that must not be restored

The complete remembered switch configuration does not include unsafe or expired transient interactions:

- Never restore synthetic key-downs, active holds, timers, pending command IDs, retries or queued input.
- Keep self-destruct disarmed. Do not restore an armed destructive control or an in-progress countdown.
- Do not restore a pending ATC request or old clearance feedback.
- Do not restore QT from this ship snapshot. QT is an independent last observed local selection from the BE;
  follow `QT-LOCAL-TARGET-BE-HANDOFF.md` and current session/log boundaries.
- Party, finances and contracts keep their own stores and are not part of the Deck snapshot.

## Persistence and capture lifecycle

Use bounded, atomic iPad-local persistence so recovery also works if the iPad application restarts.
The BE adds no history, polling, timers, endpoint or protocol fields for this feature.

Persist the latest eligible snapshot during normal use, not only on app background or a final disconnect:
a game/client crash may provide no final notification. A practical first version can retain one latest
recoverable ship snapshot per paired server; multiple named ship slots are not required by this MVP.

Preserve a valid snapshot through seat exit, ship-channel leave, PU logout/login, game-client crash,
log-generation replacement, BE restart and transport disconnect. These events can invalidate current
telemetry, but they must not erase the historical snapshot the recovery button is intended to use.
This explicitly supersedes the earlier memory-only and clear-on-session-change recommendations.

Do not overwrite a valid snapshot with startup defaults, a null ship, disabled Deck, a transient reconnect
snapshot or automatic game-ended/log-reset/destruction resets. Keep the snapshot separate from current
Deck state so these paths cannot silently replace the user's last configuration with an empty/default one.
Snapshot capture should resume only once the active/restored ship context has been established deliberately.

A verified destruction or a newly spawned ship may mean the saved configuration no longer matches reality.
Retain it as historical data, but do not auto-apply it or claim that it belongs to the replacement ship.
An intentional Reset Deck may become the new saved configuration for an established current ship;
automatic lifecycle resets must not be mistaken for that deliberate action.

## Recovery and ship identity

Only restore when the user explicitly presses the button. Present the saved ship name and timestamp so
the user can recognize what will be loaded. If no snapshot exists, show that recovery is unavailable and
keep generic Enable Deck available.

Ship name/model can be shared by multiple physical ships, and entity IDs can change after a respawn or
reload. Session/context IDs are useful historical metadata, not durable ship identity. Do not automatically
match and apply a saved configuration merely because a new ship has the same model or name.

For the intended missing-channel case, permit explicit recovery despite missing or changed server context
or entity IDs. After reconnecting and receiving a current snapshot from the paired BE, apply a local manual
override against that current session/context. Do not overwrite BE state or invent a current entity ID.
The existing paired-server identity should prevent accidental recovery from an unrelated PC's snapshot.

Restoration should update the remembered toggle set, displayed ship context and Deck availability together.
If Auto theme is enabled, the remembered manufacturer can supply the recovery theme. If it is disabled,
preserve the user's current theme selection. Theme changes alone must not alter the saved switches.

Subsequent authoritative ship-context transitions must remain able to replace/end the manual override.
Keep historical snapshot retention separate from whether that override is currently active. No callback,
binding observer or view update triggered by restoration may send a command to the game.

## FE implementation and tests on Mac

Likely FE scope: a pure snapshot value/reducer and bounded persistence helper, integration with DeckState
and the successful command-update path, the existing ShipContextTracker manual override, a ContentView
top-menu button, and en/fr/ru strings. Follow the repository's SwiftUI/Observation/Swift Testing conventions.

Required regression scenarios:

1. Save non-default gear/light/engine and other persistent switch positions; mutate/reset current state;
   press Restore; verify the complete saved configuration is reinstated exactly.
2. Repeat through seat exit, menu round-trip without a channel join, game crash, new log generation,
   BE restart, transport reconnect and iPad-store reload. Ensure the snapshot was not replaced by defaults.
3. Verify no network command, key-down/up, hold, retry or gameplay action occurs on recovery.
4. Check no snapshot, corrupted/unsupported saved data, unknown action identifiers, a different paired server,
   a same-model replacement ship, verified destruction and a new authoritative ship transition.
5. Check that rejected/pending commands do not become saved successful switch changes; self-destruct remains
   disarmed and all transient interactions are cancelled/not restored.
6. Check Auto theme on/off, Reset Deck versus Restore, en/fr/ru, accessibility, portrait and landscape.
7. Verify Party/contracts/finances and the independent server QT value are unaffected.

Build and run simulator tests on Mac, then validate the logout/login and game-client crash scenarios in game.
This document authorizes no implementation or gameplay automation by itself; it records the requested FE
design for a later coding step. The recovery feature has not been implemented or tested yet.
