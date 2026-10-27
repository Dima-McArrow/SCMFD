# CSMFD — iPad MFD for Star Citizen

CSMFD turns an iPad into a multi-function display for Star Citizen. Ship functions (flight ready, landing gear,
lights, power, quantum, ATC landing request…) and emotes sit on themed touch keys; a small companion server on the
gaming PC presses the matching game bindings and reports what it reads from `Game.log`.

This repository is the **iPad app (SwiftUI)**. The Windows server is a separate project (`SCMFDBE`, .NET 10).
Both sides follow **protocol v2**, specified in section 41 of
[`Claude outputs/CSMFD-discussion.md`](Claude%20outputs/CSMFD-discussion.md).

```text
 iPad (this app)                         Windows PC
 ┌─────────────────────┐   wss:// TLS    ┌──────────────────────────┐
 │ Deck · Emotes · Info│ ──────────────▶ │ CSMFD.Server (tray app)  │──SendInput──▶ Star Citizen
 │ ServerConnection    │ ◀────────────── │ Game.log tailer + state  │◀─Game.log──┘
 └─────────────────────┘ ack · state     └──────────────────────────┘
```

## Features

- **Deck**: four pages of MFD keys (Flight, Power, Quantum, Emergency). Taps, toggles with a lit state, and
  one-tap timed holds (e.g. quantum engage 1.5 s, self-destruct 3 s behind a slide-to-arm). Quantum target readout
  and a landing-request indicator.
- **Emotes**: 48 emote families / 132 chat commands (`/wave`, `/dance3`…), listed in
  `CSMFD/Commands/Emote.swift`.
- **Info pages**: Missions and Finances screens (currently demo data).
- **18 manufacturer themes** (RSI, Drake, Aegis, Anvil, Origin, MISC, Crusader, …) with their own palettes, fonts,
  key shapes and HUD details, plus interface sounds.
- **Localization**: English source strings with French and Russian translations (`Localizable.xcstrings`).
- **Connect to PC**: tap the link status in the top bar, scan the QR code from the server's Pair window with the
  iPad camera, type the 6-digit code. Manual address entry with a fingerprint check is the fallback.
- **Debug tab** (Debug builds only): LAN reachability check and live feedback from the server connection.

## Security model

The PC accepts input only from one paired iPad. In short:

- `wss://` only, never a plain `ws://` fallback.
- **Certificate pinning**: the iPad trusts exactly one certificate, identified by the SHA-256 fingerprint shown on the
  PC (QR code `csmfd://pair?v=2&host=…&port=47823&id=…&fp=…`, or compared by eye in manual pairing).
  Nothing is sent before the TLS check passes.
- **Pairing**: a one-time 6-digit code from the PC's Pair window, then a token stored in the iPad Keychain
  (`WhenUnlockedThisDeviceOnly`, never synced to iCloud).
- Commands carry UUIDs and get exactly one ack. After a lost connection a pending command is reported as
  *unknown*, never retried automatically.

## Requirements

- Xcode 27.1 (iOS 27.1 SDK); deployment target iOS/iPadOS 26.0.
- For a real connection: the Windows server running on the same private network
  (see the server's README for firewall and pairing steps).

## Build and test

Open `CSMFD.xcodeproj`, scheme **CSMFD**.

- **Run**: ⌘R on an iPad or the iPad simulator.
- **Test**: ⌘U. Tests use Swift Testing and run fastest on a simulator (e.g. *iPad Pro 13-inch (M5)*).

Command line:

```sh
xcodebuild -project CSMFD.xcodeproj -scheme CSMFD \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test
```

## Project layout

| Folder | Content |
|---|---|
| `CSMFD/Commands` | `ShipAction` (functions + default bindings), `KeyChord`, `Emote`, `CommandLink` transport protocol |
| `CSMFD/Controls` | MFD keys, timed hold, slide-to-arm, tick ring |
| `CSMFD/Deck` | Deck screen, `DeckState`, disconnected state, quantum readout |
| `CSMFD/Emotes` | Emote board |
| `CSMFD/Network` | Protocol v2 DTOs, pairing link parser, Keychain store, TLS pinning, session state machine, WebSocket driver |
| `CSMFD/Pairing` | Connect to PC sheet (tap the link status in the top bar) and the AVFoundation QR scanner |
| `CSMFD/Theme` | Manufacturer themes, fonts, key shapes, HUD primitives |
| `CSMFD/Settings` | Theme picker and deck settings |
| `CSMFD/Debug` | Connection test screens (Debug builds) |
| `CSMFD/Sounds`, `CSMFD/Fonts` | Interface sounds; bundled OFL fonts (licenses in `Fonts/Licenses`) |
| `CSMFDTests` | Swift Testing suites for the network layer |
| `tools` | `gen-emotes-md.py`: emote list and server `emotes.txt` from `Emote.swift` |

## Status

| Part | State |
|---|---|
| UI: Deck, Emotes, themes, sounds | Working; without a pairing the keys go to `ConsoleCommandLink` (Xcode console) |
| Protocol v2, pairing link, Keychain, TLS pinning, session logic | Implemented and unit-tested |
| Connect to PC (in-app QR scanner, 6-digit code, manual fallback), WebSocket driver, auto-reconnect | Implemented; not yet verified against the real server |
| Keys and emotes over the network: rejection feedback, hold stops on `input_cancelled` | Implemented; not yet verified in game |
| State reducer (ship context, ClearDriver, QT, ATC), auto theme | Next steps |

## Keeping the emote list in sync

The server only types emotes listed in its `emotes.txt`. After changing `Emote.swift`, regenerate the list:

```sh
python3 tools/gen-emotes-md.py CSMFD-emotes.md
```

and copy its `emotes.txt` block to `%LocalAppData%\CSMFD\emotes.txt` on the PC.
