# CLAUDE.md — SCMFD iPad app

Guidance for coding agents working in this repository. `AGENTS.md` points here; keep this file the single source.

## What this is

SwiftUI iPad app that acts as a Star Citizen MFD. It talks to a separate Windows server (`SCMFDBE`, .NET 10)
over **protocol v2**. The contract is section 41 of `Claude outputs/CSMFD-discussion.md`; section 40 (v1) is
historical. When code and spec disagree, the spec wins unless the user decides otherwise. See `README.md` for
features, layout and status.

## Build and test

- Xcode project `SCMFD.xcodeproj`, scheme **SCMFD** (it also runs the tests). Deployment target iOS 26.0, SDK 27.1.
- Prefer the Xcode MCP tools (`BuildProject`, `RunAllTests`, `RunSomeTests`, `XcodeRefreshCodeIssuesInFile`)
  over shell builds.
- Run tests on a **simulator** (e.g. *iPad Pro 13-inch (M5)*); a physical iPad makes every run slow.
- Check the active run destination (`XcodeListRunDestinations`) before running tests. If it is the physical iPad and
  the iPad is locked, Xcode cancels the run ("cancelled by a user interaction") without running a single test.
- Do not run `xcodebuild` or write to `/tmp` from the agent shell: it triggers permission prompts for folders the
  user does not know, and the shell sandbox cannot launch the simulator test runner. To count warnings, grep the
  `fullLogPath` that `BuildProject` returns.
- Commits are GPG-signed and the agent cannot reach `~/.gnupg`, even outside the sandbox. Stage the files and give
  the user the `git commit` command to run in Terminal.
- The only expected build noise is `appintentsmetadataprocessor: Metadata extraction skipped`.

## Hard rules

- **SwiftUI only. No UIKit**: no `UIViewRepresentable`, `UIViewController`, `UIDevice`, VisionKit scanners.
  Non-UI frameworks (Foundation, Network, Security, CryptoKit, AVFoundation, Vision) are fine.
- No Combine; use async/await and `@Observable`.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest.
- Code comments in English; user-facing text goes through the String Catalog (`Localizable.xcstrings`, en/fr/ru).
- Keep changes to what was asked; mention other problems instead of fixing them silently.
- Commit directly on `main`; no feature branches.

## Concurrency setup (read before adding types)

- Swift 5 language mode with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency and
  `NonisolatedNonsendingByDefault`. Everything is `@MainActor` unless marked otherwise.
- Pure data, protocol and network-logic types are declared `nonisolated` (see `SCMFD/Network`,
  `KeyEvent`, `ShipAction`). UI state is `@MainActor @Observable final class`.
- The test target has the same default isolation. Static properties used inside `@Test(arguments:)` must be
  `nonisolated static let`, or every use becomes a warning (an error in Swift 6).
- In `@Sendable` callbacks, copy a `[weak self]` capture into a `let` before using it in a `Task`.

## Network layer (`SCMFD/Network`)

| File | Role |
|---|---|
| `ProtocolV2.swift` | Wire DTOs. `hello` always encodes `"token"` (explicit `null`); UUIDs go lowercase; a state delta distinguishes a missing key (`.absent`) from `"ship": null` (`.value(nil)`). Every server enum conforms to `LenientWireEnum` with `.unrecognized(String)`, never plain `String, Decodable`: a strict enum throws on a new value, which becomes a protocol violation that never reconnects |
| `PairingPayload.swift` | Strict `csmfd://pair?…` parser (duplicates rejected), `PrivateIPv4` check |
| `ServerTrustStore.swift` | One Keychain item (`WhenUnlockedThisDeviceOnly`, not synchronizable) with host, port, fingerprint, token |
| `PinnedTLSDelegate.swift` | Accepts only the pinned certificate (SHA-256 of DER), validity and serverAuth via `SecTrust` anchored to itself, no host name check |
| `ServerSession.swift` | Pure state machine: events in, effects out. All protocol rules and timers live here and are unit-tested |
| `ServerConnection.swift` | Thin `URLSessionWebSocketTask` driver: one send loop, one receive loop, 1 s tick. One instance, owned by `ContentView` |
| `NetworkCommandLink.swift` | `CommandLink` over the server. `send` is synchronous (keeps press order) and returns a `CommandTicket` whose `outcome` resolves with the ack |

Keys follow the outcome, not the finger: a toggle flips only after its key-down is `sent`, a rejected hold stops
its animation, and `CommandOutcome.failureLabel` is shown on the key.

Security rules that must not regress:

- Never `ws://`, never "trust any certificate", never send anything before the pinned TLS check.
- Never log tokens or pairing codes.
- Never retry a command automatically or replay commands after reconnect; a lost ack means *unknown*.
- Protocol decisions belong in `ServerSession` with a test, not in the driver or the views.

## Pairing UI (`SCMFD/Pairing`)

- `QRCameraScanner`: AVFoundation only. `AVCaptureMetadataOutput` decodes QR codes; `AVCaptureVideoDataOutput`
  frames become `CGImage` for a SwiftUI `Image`. All capture state lives on one private queue (hence
  `@unchecked Sendable`); never pass `AVCaptureDevice` across contexts.
- `ConnectToPCView` is the only place that pairs or connects. The Debug tab is read-only feedback.
- Previews: pass closures (`{ handle($0) }`), not method references, in view builders; the preview thunk makes
  method references ambiguous even though the normal build accepts them.

## Project mechanics

- Folders are **file-system synchronized groups**: new files inside `SCMFD/` or `SCMFDTests/` are picked up
  automatically. Do not add file references to `project.pbxproj`.
- `SCMFDTests` is hosted in the app (`TEST_HOST`/`BUNDLE_LOADER`) and has a target dependency on `SCMFD`. Debug
  builds put the app code in `SCMFD.debug.dylib`; without the dependency, linking the tests fails with undefined
  symbols.
- Change build settings with `UpdateTargetBuildSetting`, not by editing `project.pbxproj`.

## Emotes

The server types only emotes listed in its `emotes.txt`. After editing `SCMFD/Commands/Emote.swift`, run
`python3 tools/gen-emotes-md.py <output.md>`; the generated file ends with the `emotes.txt` block for the PC. The
script fails loudly if an `EmoteGroup(...)` call has an unexpected shape.
