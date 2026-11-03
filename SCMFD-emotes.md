# SCMFD emotes

Generated from `SCMFD/Commands/Emote.swift` (2026-11-03) by `tools/gen-emotes-md.py`. Source of the commands: starcitizen.tools/Emotes (command table from 3.7 PTU).

## How the iPad sends them

- Tapping a tile sends the base command, e.g. `/wave` (the game picks a random variant).
- Numbered chips send a specific variant, e.g. `/wave1`, `/wave2`.
- Every command goes out as a protocol v2 `chat` message: `{"v":2,"type":"chat","id":"<uuid>","text":"/wave2"}`.
- The server checks `text` against `emotes.txt` (one base name per line; `/name` and `/name<N>` accepted). A name missing there is rejected.
- Exception: rows marked `key tap` (combat emotes, spec 41.27) are sent as protocol v2 `key` taps on keypad 1-6, not as chat, and are not in `emotes.txt`.

**Total:** 54 base names, 132 commands.

## Greetings

| Name | Base command | Variants | All commands |
|---|---|---|---|
| Wave | `/wave` | 2 | `/wave`, `/wave1`, `/wave2` |
| Greet | `/greet` | 2 | `/greet`, `/greet1`, `/greet2` |
| Salute | `/salute` | 2 | `/salute`, `/salute1`, `/salute2` |
| Bow | `/bow` | 6 | `/bow`, `/bow1`, `/bow2`, `/bow3`, `/bow4`, `/bow5`, `/bow6` |
| At ease | `/atease` | — | `/atease` |
| Attention | `/attention` | — | `/attention` |

## Gestures

| Name | Base command | Variants | All commands |
|---|---|---|---|
| Come | `/come` | 4 | `/come`, `/come1`, `/come2`, `/come3`, `/come4` |
| Point | `/point` | 4 | `/point`, `/point1`, `/point2`, `/point3`, `/point4` |
| Wait | `/wait` | 2 | `/wait`, `/wait1`, `/wait2` |
| Agree | `/agree` | — | `/agree` |
| Threaten | `/threaten` | 2 | `/threaten`, `/threaten1`, `/threaten2` |
| Rude | `/rude` | 3 | `/rude`, `/rude1`, `/rude2`, `/rude3` |
| Flirt | `/flirt` | — | `/flirt` |
| Chicken | `/chicken` | — | `/chicken` |

## Reactions

| Name | Base command | Variants | All commands |
|---|---|---|---|
| Cheer | `/cheer` | 8 | `/cheer`, `/cheer1`, `/cheer2`, `/cheer3`, `/cheer4`, `/cheer5`, `/cheer6`, `/cheer7`, `/cheer8` |
| Clap | `/clap` | 7 | `/clap`, `/clap1`, `/clap2`, `/clap3`, `/clap4`, `/clap5`, `/clap6`, `/clap7` |
| Laugh | `/laugh` | 3 | `/laugh`, `/laugh1`, `/laugh2`, `/laugh3` |
| Gasp | `/gasp` | 5 | `/gasp`, `/gasp1`, `/gasp2`, `/gasp3`, `/gasp4`, `/gasp5` |
| Gloat | `/gloat` | 4 | `/gloat`, `/gloat1`, `/gloat2`, `/gloat3`, `/gloat4` |
| Flex | `/flex` | 3 | `/flex`, `/flex1`, `/flex2`, `/flex3` |
| Angry | `/angry` | 3 | `/angry`, `/angry1`, `/angry2`, `/angry3` |
| Bored | `/bored` | 2 | `/bored`, `/bored1`, `/bored2` |
| Blah | `/blah` | 2 | `/blah`, `/blah1`, `/blah2` |
| Cry | `/cry` | — | `/cry` |
| Failure | `/failure` | — | `/failure` |
| Burp | `/burp` | — | `/burp` |
| Smell | `/smell` | 2 | `/smell`, `/smell1`, `/smell2` |
| Whistle | `/whistle` | 2 | `/whistle`, `/whistle1`, `/whistle2` |

## Poses

| Name | Base command | Variants | All commands |
|---|---|---|---|
| Dance | `/dance` | 6 | `/dance`, `/dance1`, `/dance2`, `/dance3`, `/dance4`, `/dance5`, `/dance6` |
| Sit | `/sit` | — | `/sit` |
| Stand | `/stand` | — | `/stand` |
| Sleep | `/sleep` | — | `/sleep` |

## Sign language

| Name | Base command | Variants | All commands |
|---|---|---|---|
| Hello | `/asl_hello` | — | `/asl_hello` |
| Goodbye | `/asl_goodbye` | — | `/asl_goodbye` |
| Nice to meet you | `/asl_meetyou` | — | `/asl_meetyou` |
| Thanks | `/asl_thanks` | 2 | `/asl_thanks`, `/asl_thanks1`, `/asl_thanks2` |
| Yes | `/asl_yes` | 2 | `/asl_yes`, `/asl_yes1`, `/asl_yes2` |
| No | `/asl_no` | 2 | `/asl_no`, `/asl_no1`, `/asl_no2` |
| Love you | `/asl_loveyou` | — | `/asl_loveyou` |
| Can't hear | `/asl_canthear` | — | `/asl_canthear` |
| Sit down | `/asl_sitdown` | 2 | `/asl_sitdown`, `/asl_sitdown1`, `/asl_sitdown2` |
| Blah | `/asl_blah` | 2 | `/asl_blah`, `/asl_blah1`, `/asl_blah2` |
| Bored | `/asl_bored` | — | `/asl_bored` |
| Exhausted | `/asl_exhausted` | — | `/asl_exhausted` |
| Sad | `/asl_sad` | — | `/asl_sad` |
| Upset | `/asl_upset` | — | `/asl_upset` |
| Angry | `/asl_angry` | — | `/asl_angry` |
| Bullshit | `/asl_bullshit` | — | `/asl_bullshit` |

## Combat

| Name | Base command | Variants | All commands |
|---|---|---|---|
| Left | `/left` | key tap `combatLeft` | — |
| Stop | `/stop` | key tap `combatStop` | — |
| Right | `/right` | key tap `combatRight` | — |
| Yes | `/yes` | key tap `combatYes` | — |
| Forward | `/forward` | key tap `combatForward` | — |
| No | `/no` | key tap `combatNo` | — |

## `emotes.txt` for the Windows server

Replace `%LocalAppData%\CSMFD\emotes.txt` with this list to match the iPad:

```text
wave
greet
salute
bow
atease
attention
come
point
wait
agree
threaten
rude
flirt
chicken
cheer
clap
laugh
gasp
gloat
flex
angry
bored
blah
cry
failure
burp
smell
whistle
dance
sit
stand
sleep
asl_hello
asl_goodbye
asl_meetyou
asl_thanks
asl_yes
asl_no
asl_loveyou
asl_canthear
asl_sitdown
asl_blah
asl_bored
asl_exhausted
asl_sad
asl_upset
asl_angry
asl_bullshit
```
