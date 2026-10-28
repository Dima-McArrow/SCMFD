# Live session rewards and contracts — first version

Implemented 2026-10-27 in the Windows BE and iPad FE sources. The Windows build/tests and real-log parser replay
can be checked here; the iPad build, Swift tests and visual validation require Xcode on the Mac.

## What changes

The Finance and Contracts screens now consume live observed activity instead of DemoSession sample entries.
Finances shows recorded reward totals by currency and recent reward notifications. It explicitly excludes spending,
fines, sales, rentals and wallet balance. The screen does not claim that recorded income equals profit.

Contracts shows observed acceptance, completion, withdrawal/failure and objectives, grouped by mission ID.
Pre-existing contracts and missing objective updates are not invented. Zero mission IDs on reward notifications
do not attach rewards to the nearest contract.

Ship changes, seat exit and iPad reconnect do not reset the tracking session. A new server/log capture starts
another session. Start new tracking session is a local zero-based boundary after the last processed event, and
is available once the connected feed has caught up. Previous sessions remain selectable.

## Lightweight BE / FE ownership

The BE reuses the existing log reader and authenticated single WebSocket send loop. It parses selected notification
facts, keeps at most 256 replay events in memory and sends pages of up to four. Acks/errors and ship state take
priority over activity replay. There is no additional polling loop, PC ledger file, wallet inference or game input.

The FE owns running totals, contract grouping, history, storage and presentation. Up to 12 sessions are saved
atomically on the iPad, with bounded recent events/contracts/objectives and a 16 MiB storage limit. The UI reports
replay gaps, incomplete history and storage failures. Currencies are counted separately.

## Reconnect behavior and limits

The source reader starts at EOF. Monitoring begun halfway through gameplay cannot recover a complete earlier
session. The first connection includes any available replay captured since BE monitoring began.

Reconnecting replays retained events with stable stream/sequence identities; existing entries are skipped.
If more than 256 events were missed, the FE flags the session incomplete. BE memory is not a durable ledger:
server restart/log-generation reset archives the prior unfinished capture as incomplete. App history persists,
but events outside replay retention cannot be reconstructed automatically.

The recent list holds 128 activity events, independent of reward totals. Contract history is capped at 128 contracts
and 32 objectives per contract; overflow is marked incomplete. History can be viewed while offline. An unreadable
history file is not overwritten with an empty one.

The current read-only first version has no manual financial entries, editable fines, transaction confirmation,
authoritative active-contract list, automatic objective-to-payout matching, Party implementation, neutral theme,
or gear tracking. Those remain separate work.

## Shared contract and tests

The additive protocol v2 `activity` message is specified in section 41.21 of
`Claude outputs/CSMFD-discussion.md`. Old clients ignore the new
message type; new clients using an older server wait for a feed rather than displaying sample transactions.
The BE reference fixture is `SCMFDBE/tests/Csmfd.Tests/Fixtures/Protocol/server-activity-rewards.json`.

BE: `dotnet build Csmfd.slnx -c Release`, `dotnet test Csmfd.slnx -c Release`, and
`dotnet format Csmfd.slnx --verify-no-changes`. New tests cover parsing/deduplication, replay/reset/end, Unicode
frame limits and real authenticated WSS delivery/replay. Local corpus replay matched 552 rewards and the
previously extracted contract counts exactly. No game input was sent during those checks.

On the Mac: clean-build the CSMFD simulator target, run the existing tests plus `SessionActivityTests`, and inspect
Finances and Contracts in landscape/portrait under the manufacturer themes. Check empty, active, saved, disconnected,
catching-up, replay-gap and storage-error states; translations are supplied for English/French/Russian UI strings.
Run a real paired session to validate event coverage and PC frametime impact. No in-game performance claim is made.
