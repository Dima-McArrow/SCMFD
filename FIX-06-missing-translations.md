# FIX-06 · Missing fr/ru translations in the String Catalog

| | |
|---|---|
| Size | M (mostly translation work) |
| Depends on | nothing; do it last or let FIX-01..04 translate their own new strings |
| Spec | — (CLAUDE.md: user-facing text goes through `Localizable.xcstrings`, en/fr/ru) |

## Problem

Measured on 2026-10-27: **114 of 165** entries in `CSMFD/Localizable.xcstrings` have no localizations at all, so
French and Russian users see English. They cover almost everything added with the network layer:

- Connect to PC and pairing (*Connect to PC*, *Scan QR code*, *6-digit code*, *Matches the PC — pair*, camera
  errors, *Forget this PC*, …)
- Key failure labels (*Busy*, *Game not focused*, *Game not running*, *Too fast*, *Expired*, *Input failed*,
  *Input paused*, *Rejected*, *Result unknown*, *No server link*, *Cancelled*, *Game lost focus*, *Ship changed*,
  *Game ended*)
- Deck states (*No ship connection*, *Enable Deck manually*, *Back in the pilot seat? …*, *Ship · No data*,
  *ATC · No data*, *Awaiting response*, *Response received*, *No confirmation · Retry*, *No active request*,
  *Request landing / takeoff*)
- Debug tab texts and Info pages (*Data source and limitations*, *WALLET / NO DATA*, …)

Two more defects in the same file:

- **Russian text used as source keys** in an English-source catalog, so English and French users see Russian:
  - `21:48:04 UTC · запрос инвентаря`
  - `Нажми кнопку слева. Панель покажет получение команды демо-сервисом.`
  - `Ожидание команды`
  - `Получена имитатором. Результат в игре неизвестен.`
  - `Создаёт только локальную демо-квитанцию. Команда не отправляется в игру.`
  - `Это точка наблюдения. Текущее положение и дальнейшее перемещение неизвестны.`

  Fix in code: English source string, Russian as the `ru` translation.
- **Values that must not be translated** are catalog entries: `192.168.1.42`, `HDPC-Farnesway`, `SCU`,
  `UEC / aUEC`. Use `Text(verbatim:)` at the call site or mark them `shouldTranslate: false`.

## Change

1. Fix the six Russian keys and the four verbatim values above.
2. Add fr and ru for every remaining entry. Keep game terms as the game shows them (Quantum, SCM/NAV, ATC, aUEC).
3. Check with (Windows: `py -3`, Mac: `python3`):

   ```sh
   python3 -c "import json; s=json.load(open('CSMFD/Localizable.xcstrings', encoding='utf-8'))['strings']; m=[k for k,v in s.items() if not v.get('localizations') and v.get('shouldTranslate', True) and k.strip()]; print(len(m), 'untranslated'); print(*m, sep='\n')"
   ```

   Done when it prints `0 untranslated` and Xcode shows no *New* / *Needs review* states for fr and ru.

## Out of scope

Changing English wording, new languages.
