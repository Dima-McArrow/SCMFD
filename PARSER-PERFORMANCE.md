# Session activity parser: local cost check

Measured on this PC on 27 October 2026 with Star Citizen closed. This measures parsing work, not game FPS.

| Measurement | Result |
|---|---:|
| Representative archived log | 11,645,381 bytes; 51,126 lines |
| Existing GameLogParser only, median | 10.8733 ms |
| Existing parser plus new ActivityJournal, median | 14.1360 ms |
| Added elapsed parsing time for the entire archive | 3.2627 ms |
| Added thread allocations over the entire archive | 857,632 bytes |

Method: load the archive into memory once, warm both paths twice, then measure nine alternating passes for each
path and compare their medians. The new path includes bounded journal storage and notification parsing. It excludes
file I/O, network serialization/transmission, iPad work and actual game frametime. Allocations are cumulative work
during this benchmark, not an increase in permanently retained memory.

The production server reuses its existing incremental log reader. It starts at EOF and processes appended lines;
it does not rescan historical archives during play. Unrelated lines pass a quick marker check without journal
locking or event allocation. The journal retains at most 256 replay events plus a bounded duplicate cache. Totals,
saved history and visual updates are on the iPad.

These results support expecting a small incremental parser cost on this PC. They do not establish zero FPS impact,
nor do they measure the complete running server. A controlled in-game frametime comparison remains necessary.

A separate read-only replay across 35 available logs matched the independent extraction exactly: 552 reward
notifications, 119 accepted-contract notifications, 240 new objectives, 87 objective completions, 39 contract
completions, 6 withdrawals and 1 failure. The number 552 describes historical reward observations, not a dictionary
of words searched on every game frame.
