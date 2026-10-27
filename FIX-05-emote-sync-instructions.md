# FIX-05 · Update the emote sync instructions

| | |
|---|---|
| Size | XS (docs only) |
| Depends on | nothing |
| Spec | 41.12 (emote allowlist agreed with `Emote.swift`) |
| Server side | done: SCMFDBE `17c17fe` (underscore stems such as `asl_thanks` accepted), `5da74ad` (full list as default) |

## Problem

`README.md` (*Keeping the emote list in sync*) and `CLAUDE.md` (*Emotes*) say the only step after editing
`Emote.swift` is to copy the generated `emotes.txt` block to `%LocalAppData%\CSMFD\emotes.txt` on the PC. That is
now incomplete:

- The server ships the full list (48 base names, 132 commands) as `ServerApp.DefaultEmotes` in SCMFDBE and writes it
  to `emotes.txt` **only when the file is missing**. An existing file on a PC is never overwritten.
- SCMFDBE has a test (`tests/Csmfd.Tests/Server/DefaultEmotesTests.cs`) that pins the count at 48.

## Change

Replace the sync instructions in both files with:

1. Edit `SCMFD/Commands/Emote.swift`.
2. Run `python3 tools/gen-emotes-md.py SCMFD-emotes.md` (prints the new totals).
3. In SCMFDBE: update `ServerApp.DefaultEmotes` (`src/Csmfd.Server/Hosting/ServerApp.cs`) with the new names, in the
   same groups and order, and the count in `DefaultEmotesTests`.
4. On a PC that already ran the server: replace `%LocalAppData%\CSMFD\emotes.txt` with the generated block (or delete
   the file to get the new default), then restart the server. It reads the file only at start; skipped invalid
   names are logged as a warning in `%LocalAppData%\CSMFD\logs`.

Name rule enforced by the server: a lowercase letter, then lowercase letters or `_`; no digits (trailing digits are
the variant number, `/dance3`). `gen-emotes-md.py` should fail if a stem breaks it: add that check next to the
existing duplicate-stem check.

## Out of scope

Generating C# from the script, or the server reading the list from the iPad: the allowlist stays a local PC file
on purpose (the PC decides what may be typed into the game).
