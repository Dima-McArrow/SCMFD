# FIX-04 · Auto theme from the ship's manufacturer

> **Superseded in part by [FIX-07](FIX-07-one-path-deck-and-theme.md) (spec 41.23, 2026-10-28):** the theme now also returns to SCMFD on `channelLeft` / `vehicleDestroyed` / `gameEnded` / `logReset`, and `state.shipContext` is the only source (the channel-activity path and `ShipChannelThemeTracker` were removed).

| | |
|---|---|
| Size | S/M |
| Depends on | FIX-02 (transition detection) |
| Spec | 41.9 (theme rules and the prefix table) |
| Server side | done: `ship.manufacturerPrefix` and `shipContext.manufacturerPrefix`, e.g. `"DRAK"` |

## Problem

`Manufacturer.logEntityPrefix` (`SCMFD/Theme/ManufacturerTheme.swift`) already lists the Game.log prefixes
(`"DRAK_"`, `"AEGS_"`, … with the trailing underscore) and is marked *reserved for automatic theme selection*, but
nothing uses it and there is no Auto theme setting. The server sends the prefix **without** the underscore.

## Change

1. `Manufacturer.init?(logPrefix: String)`: match `logEntityPrefix.dropLast()` exactly (uppercase, e.g. `"DRAK"`,
   `"XIAN"` → Aopoa, `"GAMA"` → Gatac, `"GRIN"` → Greycat). Unknown → `nil`.
2. Setting **Auto theme** in `ThemePickerView` (`@AppStorage`, e.g. `"autoTheme"`). Default is the user's call;
   suggestion: on.
3. When Auto theme is on, switch the theme **only on a transition from FIX-02 whose
   `shipContext.reason == .channelJoined`**, using `shipContext.manufacturerPrefix` (fallback
   `ship.manufacturerPrefix`). Write the same `manufacturer` storage the picker uses, so turning Auto theme off
   keeps the last theme.
4. Keep the theme unchanged on: ClearDriver, `channelLeft`, `gameEnded`, `logReset`, manual Deck enable, network
   loss, reconnect, an unknown prefix, and while Auto theme is off. A manual pick in the picker always wins until
   the next `channelJoined`.
5. Localize the new setting strings (en/fr/ru).

The server sends the manufacturer, never colours or SwiftUI enums (41.9); all styling stays on the iPad.

## Tests (Swift Testing)

- All 18 prefixes from the 41.9 table map to the right `Manufacturer`; `"FOO"` and `"DRAK_"` map to `nil`.
- Transition `channelJoined` + `"AEGS"` with Auto theme on → Aegis; same with Auto theme off → unchanged.
- ClearDriver transition → theme unchanged.
- Same-revision snapshot with a different prefix (enrichment) → unchanged.

## Out of scope

New themes, colours, fonts; the server-side prefix list.
