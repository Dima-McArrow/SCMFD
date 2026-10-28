# FIX-08 · Readable names for quantum targets

| | |
|---|---|
| Size | S/M |
| Depends on | nothing (FIX-03 already shows `qtTarget`) |
| Spec | 41.8: the UI prefers `displayName`, otherwise `internalName`; the server sends only `internalName` today |
| Source of the names | every `Player has selected point <name> as their destination` in the owner's Game.log and logbackups (80 distinct names, 2026-10-11 … 2026-10-28) |

## Problem

The QT readout shows the technical point name from Game.log: `OOC_Stanton_1_Hurston`, `LOC_RR_S2_L4`,
`rs_ext_stan-pyro_jp1`, `MISSION_QT_Quantum_Beacon_LongRange_865021957216`… Those are hard to read in flight.

A downloaded "internal names guide" (`star_citizen_internal_names.md`) was checked and **not used**: it
mislabels the Stanton planets (Stanton II is Crusader, not ArcCorp; Orison is on Crusader) and its strings
do not match the real log (`rs_ext_pyro6_orbit` vs the real `rs_ext_pyro6_leo`).

## Change

A pure, `nonisolated` lookup in the FE, e.g. `QuantumTargetName.display(for internalName: String) -> String?`,
used by the `QuantumTarget` mapping when `displayName` is null. Order: exact table, then rules, then `nil`
(the readout keeps the raw name; never invent a name). Place names are proper nouns: not localized. Generic
labels (beacons, markers) are localized strings (en/fr/ru). A server `displayName`, if it ever arrives, wins.

### 1. Rules (verified pattern, cover names not seen yet)

| Pattern | Display | Real examples |
|---|---|---|
| `OOC_Stanton_<n>[letter]_<Body>` | `<Body>` (`Microtech` → `microTech`) | `OOC_Stanton_1_Hurston` → Hurston, `OOC_Stanton_1b_Aberdeen` → Aberdeen, `OOC_Stanton_2b_Daymar` → Daymar |
| `LOC_RR_S<n>_L<k>` (Stanton Lagrange rest stops) | `<HUR\|CRU\|ARC\|MIC>-L<k>` for n = 1…4 | `LOC_RR_S1_L3` → HUR-L3, `LOC_RR_S2_L4` → CRU-L4, `LOC_RR_S3_L1` → ARC-L1 |
| `[LOC_]rs_ext_<from>-<to>_jp[1]` (jump point stations) | `<To> Gateway` (stan → Stanton, pyro → Pyro, nyx → Nyx, castra → Castra, magnus → Magnus, terra → Terra) | `LOC_rs_ext_stan-pyro_jp1` → Pyro Gateway, `rs_ext_pyro-stan_jp1` → Stanton Gateway, `rs_ext_nyx-castra_jp1` → Castra Gateway |
| `pyro<n>` | `Pyro <Roman n>` | `pyro2` → Pyro II, `pyro3` → Pyro III |
| `MISSION_QT_…` | "Mission beacon" (localized) | `MISSION_QT_Quantum_Beacon_LongRange_865021957216` |
| `NavPoint_Dynamic_<id>` | "Nav marker" (localized) | `NavPoint_Dynamic_876079337427` |
| `UnattendedVehicleMarker_<id>` | "Parked vehicle" (localized) | `UnattendedVehicleMarker_888984011374` |

### 2. Exact table (seen in the logs)

| Internal name | Display |
|---|---|
| `ObjectContainer_Lorville_City` | Lorville |
| `Area18_City_objectContainer` | Area18 |
| `NewBabbage_LOC` | New Babbage |
| `Orison_LOC` | Orison |
| `levski_all-001` | Levski |
| `ObjectContainer_RestStop` | "Rest stop" (localized; the log does not say which one) |

### 3. To confirm in game (do not ship as fact until confirmed)

Pyro station strings exist in the logs, but which station each is cannot be proven from the log alone.
Until confirmed, show a rule-based label, e.g. `rs_ext_pyro6_l5` → "Pyro VI · L5", `rs_ext_pyro3_leo` →
"Pyro III · orbit station", and switch to the name once the owner confirms it on the starmap:

| Internal name | Likely station (unconfirmed) |
|---|---|
| `rs_ext_pyro6_leo` | Ruin Station |
| `rs_ext_pyro3_leo` | Orbituary |
| `rs_ext_pyro2_l4` | Checkmate (per the downloaded guide; unverified) |
| `rs_ext_pyro6_l5` | ? |
| `P1_L3` | ? (probably Pyro I L3) |

Everything else seen (`*_cluster_*.socpak`, `ab_*`, `RegionA*_…encounter-*`, `social_001_keeger_…`,
`glaciemring_TransitPoint_Bravo`) stays raw: no reliable name.

## Tests (Swift Testing)

`@Test(arguments:)` over `(internal, expected)` pairs built from the tables above (a `nonisolated static let`),
plus:

- every example in the Rules table maps as listed;
- unknown names (`rayari_cluster_001_dust_{90B48360-…}.socpak`, `social_001_keeger_segment_rckcrk_095`) → `nil`;
- `displayName` from the server wins over the dictionary;
- `OOC_Stanton_4_Microtech` → `microTech` (casing fix).

## Out of scope

Server-side `displayName` (would need the same table on the PC; not needed while only the iPad shows names),
`freeMode` (no verified log line).
