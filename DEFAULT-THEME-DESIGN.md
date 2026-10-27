# Default theme outside a ship channel

Date: 2026-10-27

Status: corrected user requirement and implementation proposal; no runtime behavior changed by this document.
The user explicitly clarified that the default theme is triggered by leaving the ship channel, NOT by leaving
the pilot seat. This distinction is required behavior.

## Product intent

Provide a neutral CSMFD default theme when the app has no observed active ship-channel association. A matching
ship-channel join selects that ship's manufacturer theme. Leaving that channel restores the default theme.
This gives the Party, Emotes and other app pages a coherent appearance outside the ship.

Seat/control state, ship-channel association, remembered ship data and app theme are separate concerns:

- ClearDriver can turn the Deck off, cancel holds and disarm self-destruct while the ship's manufacturer theme remains.
- A verified leave of the associated ship channel selects the default theme.
- Changing theme does not erase the remembered landing-gear estimate or party state.
- Leaving a channel does not itself prove ship storage or destruction.

## Confirmed log hook

An expanded search on 2026-10-27 found 41 notification additions with the exact wording
`You have left the channel 'ship name : owner'.` in the 35-file corpus. Earlier searches for forms such as
`You have left channel` missed the word `the`; the earlier conclusion that no explicit leave was identified is
superseded by these actual records.

Examples, relative to the game's `LIVE/logbackups` directory:

| Ship | Archive | Line | UTC time |
|---|---|---:|---|
| Aurora | `Game Build(12881860) 12 Oct 26 (19 27 15).log` | 6333 | 2026-10-12T18:33:46.921Z |
| C1 Spirit | `Game Build(12913470) 17 Oct 26 (18 11 07).log` | 25034 | 2026-10-17T18:46:22.166Z |
| Cutter Rambler | `Game Build(12913470) 18 Oct 26 (18 26 39).log` | 8866 | 2026-10-18T19:05:29.928Z |
| RAFT | `Game Build(12913470) 18 Oct 26 (21 26 45).log` | 5790 | 2026-10-18T20:22:55.982Z |
| Vulture | `Game Build(12913470) 19 Oct 26 (00 48 26).log` | 22837 | 2026-10-19T04:56:04.687Z |

The Aurora's ClearDriver is earlier in the same archive at line 6320, 18:32:32.883Z. Channel leave follows
74.038 seconds later. Paris local times are 20:32:32 and 20:33:46 on 12 October. These are distinct observations.
For the RAFT, ClearDriver at line 5749 is 20:22:16.132Z; channel leave follows at 20:22:55.982Z.

These records establish an available hook, not guaranteed notification coverage for every possible way of leaving.
Generic Channel Disconnected messages describe game/network channels, and communications call teardown can concern
ATC or another partner. Neither is a substitute for the explicit ship-channel notification.

## BE readiness and required extension

The existing BE already publishes manufacturer prefixes, revisioned ship context, and matching ClearDriver
transitions. Protocol ShipContextReason includes ChannelLeft, but the inspected GameLogParser does not parse
the explicit notification and GameLogProcessor does not emit ChannelLeft from it. Therefore the BE is close,
but is not fully ready for this exact feature.

More importantly, its active ship slot represents assumed control: ClearDriver clears that slot. A null ship
or noShip status therefore cannot answer whether the player still belongs to a ship channel.

Retain the last observed ship-channel association separately from active control, so a leave arriving after
ClearDriver can still be recognized. This is a small amount of state, not another reader or polling loop.

Required BE work:

1. Parse the explicit notification as a distinct ship-channel-left observation, counting only new notification
   additions, not queue reprints or fade/removal updates.
2. Match the leaving channel to the currently associated channel by the available ship name and owner identity.
   A leave for another or previously replaced ship must not clear the new association. Do not invent an EntityId
   or channel UUID that the notification does not provide. Ambiguous association remains unknown.
3. Preserve channel association across ClearDriver. Clear it on a matching explicit channel leave or game-session
   end/log reset, with unknown status where continuity is lost.
4. Publish sufficient independently revisioned channel state for a reconnecting FE full snapshot. Emitting only
   a transient ChannelLeft reason is insufficient: later control transitions can overwrite it, and the current
   control snapshot cannot distinguish seat exit from channel absence.
5. Specify how a channel leave affects existing control-context/manual-override rules without duplicating key
   releases or using the same revision to mean both control and channel membership.

The exact wire representation is open: a dedicated channel-association field or another explicitly independent
summary can work. Do not claim that an existing null ship field is enough or ship an undocumented new message.
Update the canonical spec, fixtures, BE and FE DTOs/state handling and tests together.

Handle names such as `Drake Vulture Teach's Special`: the current join regex excludes apostrophes in ship names.
Match C1 channel/model names explicitly where word order differs. Use observed prefix mappings; the server sends
facts and manufacturer prefixes, never colors, font names or SwiftUI theme identifiers.

## FE theme policy

The following is the proposed automatic-mode policy. The user's trigger is mandatory; disconnected presentation
and manual-theme preferences below are proposed defaults to finalize during implementation.

| Situation | Theme |
|---|---|
| Launch before any established ship-channel association | Default |
| Matching channel join with a supported manufacturer | Manufacturer theme |
| Seat exit / matching ClearDriver only | Keep the channel's manufacturer theme |
| Explicit leave of the associated ship channel | Default |
| Leave for another/older channel | Unchanged |
| Return to the seat while association remains | Keep manufacturer theme; no new channel join required |
| New ship channel replaces the old association | New manufacturer's theme |
| Associated channel with an unsupported manufacturer | Default as a neutral fallback |
| Confirmed game-session end | Default; channel association ended with that session |
| Log reset / lost observation continuity | Default as an unknown-state fallback, not a claim that channel leave occurred |
| Temporary transport loss with previously known association | Retain last theme while disconnected; reconcile from the next full snapshot |
| Manual deck enable | Do not invent a channel join or change theme from control state alone |

Full snapshots and deltas must merge correctly: an absent channel field preserves it; an explicit clear removes
it according to the chosen contract. Repeated same-revision state must not replay theme changes. A stale
manufacturerPrefix retained in a control context must not bring a manufacturer theme back after channel leave.

Use a distinct default app theme, not a fake manufacturer or log prefix. Refactor presentation selection if
necessary so the theme picker and app branding can represent neutral CSMFD as well as manufacturer themes.
Exact colors, typography and default-theme visual styling are separate design work; this note does not prescribe them.

**Done (FE):** the default theme exists as `AppTheme.standard` / `ManufacturerTheme.standard`. By the user's choice it
reuses every RSI token (palette, fonts, keys, backdrop) and shows the untranslated app name `SCMFD` /
`Star Citizen MFD` instead of RSI. It has no `Manufacturer` and no log prefix. It is first in the picker and the
default for new installs; a stored manufacturer choice (e.g. `"rsi"`) keeps decoding under the same storage key.

Keep manual theme choice separate from automatic selection. Suggested settings behavior: Auto theme enabled by
default; disabling it uses the user's explicit theme choice (default can also be selectable). Do not overwrite
that manual preference whenever automatic selection changes. Manual overrides must not accidentally change the
meaning of observed channel membership.

Default theme does not mean a black screen or disabled Party tab. Deck enablement stays governed by control
state and existing manual override rules. Theme transitions should animate on the iPad and respect reduced-motion
preferences. User-visible labels belong in the existing en/fr/ru string catalog.

## Relationship to existing notes

`FIX-02-server-state-drives-the-deck.md` remains the prerequisite for merged state and control transitions.
`FIX-04-auto-theme-from-manufacturer.md` currently keeps the theme on channelLeft as well as ClearDriver.
This new request changes the channelLeft policy while preserving the seat-exit distinction. The canonical
section 41 and FIX-04 must be reconciled during implementation; this document does not silently amend the protocol.

`LANDING-GEAR-TRACKING-DESIGN.md` remains separate: deck resets, theme changes and channel leave must not reset
gear to down. Only a recognized fresh retrieval cycle establishes the down assumption; destruction or uncertainty
can end/invalidate the estimate. `PARTY-TAB-DESIGN.md` stays independent of ship control/channel lifecycle.

## Verification

BE fixtures/tests: explicit leave after ClearDriver, apostrophe-bearing Vulture names, C1 association, duplicate
notifications, unrelated/late leave, rapid old-leave/new-join sequences, reset, and correct full reconnect snapshots.

FE deterministic tests: default at launch, manufacturer on join, no theme change on ClearDriver, default on
matching channel leave, no stale-prefix restoration, reconnect reconciliation, unknown manufacturer, manual
settings, manual deck enable, and retained gear/party state through theme changes.

In game, record times while entering a ship, sitting, leaving the seat without leaving the ship, returning to
the seat, leaving the ship/channel, re-entering, and switching ships. Compare explicit channel notifications to
the actual actions and check notification coverage. Do not use a timeout or seat exit to fabricate channel leave.
