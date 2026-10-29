# Proposal: manual recovery of the last observed ship context

Date: 2026-10-29.

Status: proposal only, not implemented. The owner asked what a top-menu recovery button would take.
Only BE code is being changed in the current step; this file is the FE handoff.

## Why this is useful

The inspected logs show a ship channel join, PU exit, then PU reentry and further local navigation without
a repeated ship-channel notification. Automatically restoring a trusted current ship from those facts is
not justified. The user can, however, explicitly confirm that they returned to the same ship.

## Suggested MVP

Extend the existing iPad-side Enable Deck behavior with a top-menu action such as "Recover last ship".
The iPad remembers the last observed ship name and recognized manufacturer separately from the current
server snapshot. On a manual recovery, it can enable Deck and show that remembered identity as historical,
with an explicit "Restored manually / last observed" indication and its observation time.

The action is local UI recovery. It sends no commands, no synthetic keys and no new BE requests. It does
not overwrite the server's ship status, infer a current entity ID or claim the player is in a pilot seat.
Do not blindly restore the states of switches such as gear, shields or lights: their real states may have
changed during logout. Keep existing key behavior; never replay held keys or pending commands.

Recommended behavior:

- Enable only while paired/connected and after receiving the current server snapshot, with a remembered ship.
  A missing remembered ship leaves the existing generic Enable Deck action available.
- Bind the manual override to the current server session/context, as Enable Deck already does. The next
  authoritative ship transition takes precedence and ends/replaces the override under the existing rules.
- Apply the remembered manufacturer through the existing Auto theme preference. If Auto theme is off,
  preserve the user's selected theme.
- Keep a distinct manual/historical label while server ship identity remains unknown/noShip. This is a user
  assumption, not automatic reconciliation with the log.
- Never restore old QT from the remembered ship. QT is the separate last observed local selection; the
  server already clears it at PU/game/log boundaries and publishes a new selection when observed.
- Prefer memory-only retention for the first version. Clear the recovery candidate on log reset, a different
  server/process session or verified destruction of that ship; keep it through a menu round-trip in the same
  session. Avoid restoring a remembered ship from yesterday as current state.
- Support en/fr/ru, accessibility and the top bar's compact/scrolling layout.

## Scope and checks

This should fit mainly in the FE tracker/state, ContentView top bar and localization catalog, with a small
remembered-context value. No BE roster, caching service, second reader, polling or wire extension is needed.
Exact interaction design and lifecycle details need FE implementation and simulator validation on Mac.

Test: no candidate, menu exit/reentry without channel join, manual recovery, authoritative new join,
destruction/log reset/server-session changes, Auto theme off, disconnect and no replay of game input.
Verify that recovery does not change Party, contracts, finances or the independent QT observation.

The button restores a usable interface based on the user's assumption. It cannot recover unlogged actual
ship systems, current physical switches, active keys or an authoritative current game state.
