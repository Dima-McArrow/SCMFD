# FIX-01 · Labels for every server cancel and reject reason

| | |
|---|---|
| Size | S |
| Depends on | nothing |
| Spec | 41.10 (`input_cancelled` / `auto_released` reasons, ack reject reasons) |
| Server side | done; `session_locked` is sent since SCMFDBE `75e0c37` |

## Problem

- `InterruptionReason.label(for:)` in `CSMFD/Commands/CommandLink.swift` knows 4 of the 11 reasons the server
  sends with `input_cancelled` / `auto_released`. Every other reason shows the generic **Cancelled**, including the
  new `session_locked` (Windows locked with Win+L, user switch, RDP disconnect, logoff).
- `CommandOutcome.failureLabel` shows the generic **Rejected** for `invalid`. That is the answer the user gets when
  the PC's `emotes.txt` does not list an emote, so it needs its own text.

## Change

1. Replace the string `switch` in `InterruptionReason` with a `nonisolated enum CancelReason: String` mirroring the
   wire values (same pattern as `RejectReason` in `ProtocolV2.swift`), and map each case to a label. Unknown raw
   values keep **Cancelled**.

   | Wire reason | English (source) | fr | ru |
   |---|---|---|---|
   | `focus_lost` | Game lost focus *(exists)* | Le jeu a perdu le focus | Игра потеряла фокус |
   | `session_locked` | PC locked | PC verrouillé | ПК заблокирован |
   | `game_ended` | Game ended *(exists)* | Jeu terminé | Игра завершена |
   | `ship_context_changed` | Ship changed *(exists)* | Vaisseau changé | Корабль сменился |
   | `paused` | Input paused *(exists)* | Saisie en pause | Ввод на паузе |
   | `client_replaced` | Another device took over | Un autre appareil a pris la main | Управление перехвачено |
   | `revoked` | iPad unpaired | iPad dissocié | iPad отвязан |
   | `disconnected` | Connection lost | Connexion perdue | Связь потеряна |
   | `watchdog` | Auto-released | Relâché automatiquement | Отпущено автоматически |
   | `shutdown` | Server stopped | Serveur arrêté | Сервер остановлен |
   | `release_all` | Released | Relâché | Отпущено |

2. In `CommandOutcome.failureLabel` add `case .invalid: "Not allowed on PC"` (fr *Non autorisé sur le PC*,
   ru *Не разрешено на ПК*). `duplicate`, `unknown_action`, `unknown_key` stay **Rejected**: they mean a client bug,
   not something the user can act on. `cancelled` → existing **Cancelled** key.
3. Add every new string to `Localizable.xcstrings` with fr and ru (wording above is a proposal; adjust freely).

Note: `client_replaced`, `revoked`, `disconnected` and `shutdown` usually arrive right before the socket closes, so a
key may resolve as *Result unknown* instead. That is expected; do not add retries or waits for it.

## Tests (Swift Testing, `CSMFDTests`)

- `@Test(arguments:)` over the 11 wire reasons (a `nonisolated static let`): each maps to its own label, never to
  the fallback `Cancelled`.
- An unknown reason (`"something_new"`) and `nil` map to **Cancelled**.
- `CommandOutcome.rejected("invalid").failureLabel` has the key `Not allowed on PC`.

## Out of scope

No protocol change, no change to when keys stop animating (that already follows `interruptions(of:)`).
